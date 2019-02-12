
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

		console.log expectation.toHex()

		expect transaction.getId()
			.toBe expectation.getId()

		expect transaction.toHex()
			.toBe expectation.toHex()

		return
