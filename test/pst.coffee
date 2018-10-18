
import PartiallySignedTransaction 		from '../index'
import crypto 							from 'crypto'
import { TransactionBuilder, networks, ECPair, payments } from 'bitcoinjs-lib'

describe 'PartiallySignedTransaction', ->

	network = networks.testnet

	pairs = [1, 2, 3].map (i) ->
		hash = crypto.createHash 'sha256'
			.update String i
			.digest()

		return ECPair.fromPrivateKey hash, { network }

	pubkeys = pairs.map (pair) ->
		return pair.publicKey


	it 'should create a transaction from pst', ->

		# --------------------------------------------------------
		# Build the partial transaction

		pst = new PartiallySignedTransaction network

		pst.addInput {
			txid: 		'6ba496843fb9d0912837da1a8bcd4e2817a8caf2a1ede2498de735105935d281'
			vout: 		0
			sequence: 	0xffffffff
			address:	'2N3t4KPt9dpnYXJX4m3QpGmTt82Ry4N6u7G'
			script: 	'16001472432cb0514f964326b8e5dbd457b21cf1d3200c'
			value: 		11000
		}

		pst.addOutput {
			address:	'2N3t4KPt9dpnYXJX4m3QpGmTt82Ry4N6u7G'
			value: 		10000
		}

		# --------------------------------------------------------
		# Simulate broadcasting of the PST

		pst = PartiallySignedTransaction.fromHex pst.toHex(), network

		# --------------------------------------------------------
		# Add redeem & witness script

		p2ms 	= payments.p2ms { m: 2, pubkeys, network }
		p2wsh 	= payments.p2wsh { redeem: p2ms, network }
		p2sh 	= payments.p2sh { redeem: p2wsh, network }

		pst.addScript 0, p2sh.redeem.output, p2wsh.redeem.output

		# --------------------------------------------------------
		# Sign an input

		pst.sign 0, pairs[0]

		# --------------------------------------------------------
		# Simulate broadcasting of the PST

		pst = PartiallySignedTransaction.fromHex pst.toHex(), network

		# --------------------------------------------------------
		# Co-sign an input

		pst.sign 0, pairs[1]

		# --------------------------------------------------------
		# Simulate broadcasting of the PST

		pst = PartiallySignedTransaction.fromHex pst.toHex(), network

		# --------------------------------------------------------
		# Co-sign an input

		pst.sign 0, pairs[2]

		# --------------------------------------------------------
		# Simulate broadcasting of the PST

		pst = PartiallySignedTransaction.fromHex pst.toHex(), network

		# --------------------------------------------------------
		# Finalize / Build the transaction.

		transaction = pst.build()

		# --------------------------------------------------------

		expect pst.getFee().toString()
			.toBe '1000'

		expect pst.getInputAmount().toString()
			.toBe '11000'

		expect pst.getOutputAmount().toString()
			.toBe '10000'

		# --------------------------------------------------------

		expect transaction.getId()
			.toBe '9057fa857f9a66ef9cdcda8584f835fd3c861ced41fdbedae5a4f32011c007d9'

		# --------------------------------------------------------

		input = transaction.ins[0]

		expect input.hash.toString 'hex'
			.toBe '81d235591035e78d49e2eda1f2caa817284ecd8b1ada372891d0b93f8496a46b'

		expect input.sequence
			.toBe 0xffffffff

		expect input.script
			.toBeDefined()

		expect input.witness.length
			.toBeGreaterThan 0

		# --------------------------------------------------------

		output = transaction.outs[0]

		expect output.script
			.toBeDefined()

		expect output.value
			.toBe 10000


		# --------------------------------------------------------
		# Create a transaction the normal way and see if it
		# matches our pst transaction.

		builder = new TransactionBuilder network
		builder.addInput(
			Buffer.from(pst.inputs[0].txid, 'hex').reverse()
			pst.inputs[0].vout
			pst.inputs[0].sequence
			Buffer.from pst.inputs[0].script, 'hex'
		)

		builder.addOutput(
			pst.outputs[0].address
			pst.outputs[0].value
		)

		p2ms 	= payments.p2ms { m: 2, pubkeys, network }
		p2wsh 	= payments.p2wsh { redeem: p2ms, network }
		p2sh 	= payments.p2sh { redeem: p2wsh, network }

		for pair in pairs
			builder.sign(
				0
				pair
				p2sh.redeem.output
				null
				pst.inputs[0].value
				p2wsh.redeem.output
			)

		expectation = builder.build()

		expect transaction.getId()
			.toBe expectation.getId()

		expect transaction.toHex()
			.toBe expectation.toHex()

		return
