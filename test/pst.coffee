
import PartiallySignedTransaction 		from '../index'
import { networks, ECPair, payments } 	from 'bitcoinjs-lib'
import crypto 							from 'crypto'

describe 'PartiallySignedTransaction', ->

	network = networks.testnet

	keyPairs = [1, 2, 3].map (i) ->
		hash = crypto.createHash 'sha256'
			.update String i
			.digest()

		return ECPair.fromPrivateKey hash, { network }

	pubkeys = keyPairs.map (pair) ->
		return pair.publicKey

	it 'should create a transaction', ->

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

		pst.sign 0, keyPairs[0]

		# --------------------------------------------------------
		# Simulate broadcasting of the PST

		pst = PartiallySignedTransaction.fromHex pst.toHex(), network

		# --------------------------------------------------------
		# Co-sign an input

		pst.sign 0, keyPairs[1]

		# --------------------------------------------------------
		# Simulate broadcasting of the PST

		pst = PartiallySignedTransaction.fromHex pst.toHex(), network

		# --------------------------------------------------------
		# Co-sign an input

		pst.sign 0, keyPairs[2]

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
			.toBe '115393aa809c721bc36de7c4f5f52f4190222067970714fceb298087f8aa729b'

		expect transaction.toHex()
			.toBe [
				'020000000001016ba496843fb9d0912837da1a8bcd4e2817a8caf2a1ede2498de735'
				'105935d2810000000023220020cbe6dc447159db36b21aa011207073e93c196adb4d'
				'd71614aaed4f12bf9a00e1ffffffff01102700000000000017a91474a8936e59d193'
				'813080bf514a412e8ff385c98287050047304402203ca4889be7d9090db69c8cb67d'
				'6bd34e70bea15971ce7f2638ee538a8c3334e002207a4f4997c90ba0a10aa1e20e43'
				'7c40127da4eeb43ef86e6a936a1d0c857e382801473044022033ea0a23a9854710bd'
				'2ddbac3abd2c49a2738b4f46cc246da540a728702f9797022057ad8b0207289838e3'
				'60dab8851f27aff31a8bb6056ddb738170a008fe7490d0014730440220321665c1bf'
				'f43958b29c7124b211f6dde8d8bb5506fdbefa6f3bc444382089fb02205a0148387f'
				'212b9c1599add39629db339049916135adabf0d9852caf44532f710169522103fdf4'
				'907810a9f5d9462a1ae09feee5ab205d32798b0ffcc379442021f84c5bbf21039ebd'
				'374eea3befddf46bbb182e291fb719ee1b705b0b7802161038eb7da8a0362102b091'
				'5b333926d5338cadba614164c99be83592a13d8bdecb6f679593c11b79d853ae0000'
				'0000'
			].join ''

		# --------------------------------------------------------

		input = transaction.ins[0]

		expect input.hash.toString 'hex'
			.toBe '6ba496843fb9d0912837da1a8bcd4e2817a8caf2a1ede2498de735105935d281'

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

		return
