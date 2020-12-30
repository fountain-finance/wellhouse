// https://gist.github.com/RickCarlino/41b8ddd36e41e381c132bbfcd1c31f3a#file-jsonrpc2-ts

/** A String specifying the version of the JSON-RPC protocol. MUST be exactly "2.0". */
type JsonRpcVersion = '2.0'

export type JsonRpcId = number | string | void

export interface JsonRpcResponse {
  jsonrpc: JsonRpcVersion
  id: JsonRpcId
}

export interface JsonRpcSuccess<T> extends JsonRpcResponse {
  result: T
}

export interface JsonRpcFailure<T> extends JsonRpcResponse {
  error: JsonRpcError<T>
}

export interface JsonRpcError<T> {
  /** Must be an integer */
  code: number
  message: string
  data?: T
}
