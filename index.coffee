
import { TransactionBuilder, address as baddr } from 'bitcoinjs-lib'
import Big from 'big.js'

export default class PartiallySignedTransaction

	@SIGNED_INPUT_PROPERTIES = [
		'value'
		'prevOutScript'
		'prevOutType'
		'redeemScript'
		'redeemScriptType'
		'witnessScript'
		'witnessScriptType'
		'hasWitness'
		'signScript'
		'signType'
		'signatures'
		'pubkeys'
	]

	@BUFFER_PROPERTIES = [
		'prevOutScript'
		'redeemScript'
		'witnessScript'
		'signScript'

		'txid'
		'script'
	]

	@INPUT_PROPERTIES = [
		'txid'
		'vout'
		'value'
		'address'
		'sequence'
		'script'
	]

	@OUTPUT_PROPERTIES = [
		'address'
		'value'
	]

	@fromHex = (hex, network) ->
		buffer 	= Buffer.from hex, 'hex'
		json 	= buffer.toString 'utf8'
		data 	= JSON.parse json

		pst = new PartiallySignedTransaction network
		pst.inputs 	= data.inputs
		pst.outputs = data.outputs

		return pst

	constructor: (@network) ->
		@inputs 	= []
		@outputs 	= []

	_filter: (object, filter) ->
		filtered = {}

		for prop, value of object
			if filter.includes prop
				filtered[prop] = value

		return filtered

	_serializeArray: (array) ->
		if not Array.isArray array
			return array

		serialized = []
		for value in array
			if Buffer.isBuffer value
				serialized.push value.toString 'hex'
			else
				serialized.push value

		return serialized

	_unserializeArray: (array) ->
		if not Array.isArray array
			return array

		unserialized = []
		for value in array
			if typeof value is 'string'
				unserialized.push Buffer.from value, 'hex'
			else
				unserialized.push value

		return unserialized

	_serialize: (object) ->
		serialized = {}
		for prop, value of object
			if Buffer.isBuffer value
				serialized[prop] = value.toString 'hex'
			else
				serialized[prop] = value

		return serialized

	_unserialize: (object) ->
		unserialized = {}
		for prop, value of object
			if PartiallySignedTransaction.BUFFER_PROPERTIES.includes prop
				unserialized[prop] = Buffer.from value, 'hex'
			else
				unserialized[prop] = value

		return unserialized

	addInput: (input) ->
		@inputs.push @_serialize @_filter(
			input
			PartiallySignedTransaction.INPUT_PROPERTIES
		)

		return @

	addOutput: (output) ->
		@outputs.push @_serialize @_filter(
			output
			PartiallySignedTransaction.OUTPUT_PROPERTIES
		)

		return @

	addScript: (index, redeemScript, witnessScript) ->
		input = @inputs[index]
		input.redeemScript = redeemScript.toString 'hex'
		if witnessScript
			input.witnessScript = witnessScript.toString 'hex'

		return @

	addRedeemScript: (index, script) ->
		input = @inputs[index]
		input.redeemScript = script.toString 'hex'

		return @

	addWitnessScript: (index, script) ->
		input = @inputs[index]
		input.witnessScript = script.toString 'hex'

		return @

	sign: (index, keyPair) ->

		builder	= new TransactionBuilder @network

		for input in @inputs
			input = @_unserialize input
			builder.addInput(
				input.txid.reverse()
				parseInt input.vout, 10
				input.sequence 	or null
				input.script 	or null
			)

		for output in @outputs
			output = @_unserialize output
			builder.addOutput(
				output.address
				output.value
			)

		input = @inputs[index]
		entry = builder.__inputs[index]

		# ---------------------------------------------
		# Sign the transaction

		input = @_filter input, PartiallySignedTransaction.SIGNED_INPUT_PROPERTIES
		input = @_unserialize input

		if input.signatures
			input.signatures = @_unserializeArray input.signatures

		if input.pubkeys
			input.pubkeys = @_unserializeArray input.pubkeys

		Object.assign entry, input

		builder.sign(
			index
			keyPair
			input.redeemScript or null
			null
			input.value
			input.witnessScript or null
		)

		# ---------------------------------------------
		# Save the signed input information.
		# Currently we save a list of properties from
		# the transaction builder. This will hopefully
		# improve when the lib supports PSBT bip-0174

		entry = @_filter entry, PartiallySignedTransaction.SIGNED_INPUT_PROPERTIES
		entry = @_serialize entry

		if entry.signatures
			entry.signatures = @_serializeArray entry.signatures

		if entry.pubkeys
			entry.pubkeys = @_serializeArray entry.pubkeys

		Object.assign @inputs[index], entry

		return @

	build: ->

		builder	= new TransactionBuilder @network

		for input in @inputs
			input = @_unserialize input
			builder.addInput(
				input.txid.reverse()
				parseInt input.vout, 10
				input.sequence
				input.script
			)

		for output in @outputs
			output = @_unserialize output
			builder.addOutput(
				output.address
				output.value
			)

		index = 0
		for input in @inputs
			entry = builder.__inputs[index]

			input = @_filter input, PartiallySignedTransaction.SIGNED_INPUT_PROPERTIES
			input = @_unserialize input
			input.signatures 	= @_unserializeArray input.signatures
			input.pubkeys 		= @_unserializeArray input.pubkeys

			Object.assign entry, input

			index++

		# ---------------------------------------------
		# Build the signed transaction

		return builder.build()


	getFee: ->
		return new Big 0
			.plus @getInputAmount()
			.minus @getOutputAmount()

	getOutputAmount: ->
		amount = new Big 0
		for output in @outputs
			amount = amount.plus output.value

		return amount

	getInputAmount: ->
		amount = new Big 0
		for input in @inputs
			amount = amount.plus input.value

		return amount

	toJson: ->
		return JSON.stringify {
			inputs: 	@inputs
			outputs: 	@outputs
			hex: 		@hex
		}

	toBuffer: ->
		return Buffer.from @toJson(), 'utf8'

	toHex: ->
		return @toBuffer().toString 'hex'
