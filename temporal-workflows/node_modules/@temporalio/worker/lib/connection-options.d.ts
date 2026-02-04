import { native } from '@temporalio/core-bridge';
import { ProxyConfig, TLSConfig } from '@temporalio/common/lib/internal-non-workflow';
import type { Metadata } from '@temporalio/client';
import type { NativeConnectionPlugin } from './connection';
export { TLSConfig, ProxyConfig };
export interface NativeConnectionOptions {
    /**
     * The address of the Temporal server to connect to, in `hostname:port` format.
     *
     * Port defaults to 7233. Raw IPv6 addresses must be wrapped in square brackets (e.g. `[ipv6]:port`).
     *
     * @default localhost:7233
     */
    address?: string;
    /**
     * TLS configuration options.
     *
     * Pass a falsy value to use a non-encrypted connection or `true` or `{}` to
     * connect with TLS without any customization.
     */
    tls?: TLSConfig | boolean | null;
    /**
     * Proxying configuration.
     */
    proxy?: ProxyConfig;
    /**
     * Optional mapping of gRPC metadata (HTTP headers) to send with each request to the server.
     *
     * Set statically at connection time, can be replaced later using {@link NativeConnection.setMetadata}.
     */
    metadata?: Metadata;
    /**
     * API key for Temporal. This becomes the "Authorization" HTTP header with "Bearer " prepended.
     * This is only set if RPC metadata doesn't already have an "authorization" key.
     */
    apiKey?: string;
    /**
     * If set to true, error code labels will not be included on request failure
     * metrics emitted by this Client.
     *
     * @default false
     */
    disableErrorCodeMetricTags?: boolean;
    /**
     * List of plugins to register with the native connection.
     *
     * Plugins allow you to configure the native connection options.
     *
     * Any plugins provided will also be passed to any Worker, Client, or Bundler built from this connection.
     *
     * @experimental Plugins is an experimental feature; APIs may change without notice.
     */
    plugins?: NativeConnectionPlugin[];
}
export declare function toNativeClientOptions(options: NativeConnectionOptions): native.ClientOptions;
