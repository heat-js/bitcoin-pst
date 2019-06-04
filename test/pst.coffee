
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


	it 'should create a P2SH(P2WSH(P2MS(2 out of 3))) transaction from pst', ->

		# --------------------------------------------------------
		# Build the partial transaction

		pst = new PartiallySignedTransaction network

		pst.addInput {
			txid: 		'7bc20f323aa79cfa893a2af8715f06f911f2eeef60cec5d6fa98688dceed699d'
			vout: 		0
			sequence: 	0xffffffff
			address:	'2Mz2SLP6sUfZb7oJX8hsyFCyxpJupXbv23f'
			script: 	'a9144a5dc78289a3437c85ab4b25c072cac23a938a1587'
			value: 		70000
		}

		pst.addOutput {
			address:	'2Mz2SLP6sUfZb7oJX8hsyFCyxpJupXbv23f'
			value: 		69000
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
		# Sign the input with each private key

		for pair in pairs

			pst.sign 0, pair

			# ----------------------------------------------------
			# Simulate broadcasting of the PST

			pst = PartiallySignedTransaction.fromHex(
				pst.toHex()
				network
			)

		# --------------------------------------------------------
		# Finalize / Build the transaction.

		transaction = pst.build()

		# --------------------------------------------------------

		expect pst.getFee().toString()
			.toBe '1000'

		expect pst.getInputAmount().toString()
			.toBe '70000'

		expect pst.getOutputAmount().toString()
			.toBe '69000'

		# --------------------------------------------------------

		expect transaction.getId()
			.toBe '37e064e846ab7bca804f60ce3da0c332480313dbef6985473e506a79e8b32a98'

		# --------------------------------------------------------

		input = transaction.ins[0]

		expect input.hash.toString 'hex'
			.toBe '9d69edce8d6898fad6c5ce60efeef211f9065f71f82a3a89fa9ca73a320fc27b'

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
			.toBe 69000

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

	it 'should create a P2SH(P2WPKH) transaction from pst', ->

		p2wpkh 	= payments.p2wpkh { pubkey: pubkeys[0], network }
		p2sh 	= payments.p2sh { redeem: p2wpkh, network }
		address = p2sh.address

		# --------------------------------------------------------
		# Build the partial transaction

		pst = new PartiallySignedTransaction network

		pst.addInput {
			txid: 		'6ba496843fb9d0912837da1a8bcd4e2817a8caf2a1ede2498de735105935d281'
			vout: 		0
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

		pst.addRedeemScript 0, p2sh.redeem.output

		# --------------------------------------------------------
		# Sign an input

		pst.sign 0, pairs[0]

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
			.toBe '986a62ad90ff7352ca0f038435d22031427c638d52941e2af888e27aa047d0be'

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
		)

		builder.addOutput(
			pst.outputs[0].address
			pst.outputs[0].value
		)

		builder.sign(
			0
			pairs[0]
			p2sh.redeem.output
			null
			pst.inputs[0].value
		)

		expectation = builder.build()

		expect transaction.getId()
			.toBe expectation.getId()

		expect transaction.toHex()
			.toBe expectation.toHex()

		return

	it 'should be able to build the transaction before the transaction is signed', ->

		p2wpkh 	= payments.p2wpkh { pubkey: pubkeys[0], network }
		p2sh 	= payments.p2sh { redeem: p2wpkh, network }
		address = p2sh.address

		# --------------------------------------------------------
		# Build the partial transaction

		pst = new PartiallySignedTransaction network

		pst.addInput {
			txid: 		'6ba496843fb9d0912837da1a8bcd4e2817a8caf2a1ede2498de735105935d281'
			vout: 		0
			value: 		11000
		}

		pst.addOutput {
			address:	'2N3t4KPt9dpnYXJX4m3QpGmTt82Ry4N6u7G'
			value: 		10000
		}

		pst.addRedeemScript 0, p2sh.redeem.output
		pst.sign 0, pairs[0]

		expect pst.buildIncomplete().getId()
			.not.toBe pst.build().getId()
