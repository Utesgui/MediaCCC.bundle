using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.MediaCCC.Api.Models;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.MediaCCC.Api
{
    /// <summary>
    /// API-Client für die Voctoweb JSON-API.
    /// </summary>
    public class VoctowebApiClient
    {
        private readonly ILogger<VoctowebApiClient> _logger;
        private readonly HttpClient _httpClient;
        private const string BaseUrl = "https://api.media.ccc.de/public";

        /// <summary>
        /// Initializes a new instance of the <see cref="VoctowebApiClient"/> class.
        /// </summary>
        /// <param name="logger">Logger-Instanz.</param>
        /// <param name="httpClient">HttpClient-Instanz.</param>
        public VoctowebApiClient(ILogger<VoctowebApiClient> logger, HttpClient httpClient)
        {
            _logger = logger;
            _httpClient = httpClient;
        }

        /// <summary>
        /// Ruft eine Liste von Konferenzen ab.
        /// </summary>
        /// <param name="cancellationToken">Abbruch-Token.</param>
        /// <returns>Eine Liste von Konferenzen.</returns>
        public async Task<List<Conference>> GetConferencesAsync(CancellationToken cancellationToken)
        {
            var url = $"{BaseUrl}/conferences";
            _logger.LogInformation("Fetching conferences from {Url}", url);

            var response = await _httpClient.GetAsync(url, cancellationToken).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();

            var content = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            return JsonSerializer.Deserialize<List<Conference>>(content);
        }

        /// <summary>
        /// Ruft Details zu einer Konferenz ab.
        /// </summary>
        /// <param name="conferenceId">Die ID der Konferenz.</param>
        /// <param name="cancellationToken">Abbruch-Token.</param>
        /// <returns>Details der Konferenz.</returns>
        public async Task<ConferenceDetail> GetConferenceDetailAsync(string conferenceId, CancellationToken cancellationToken)
        {
            var url = $"{BaseUrl}/conferences/{conferenceId}";
            _logger.LogInformation("Fetching conference details from {Url}", url);

            var response = await _httpClient.GetAsync(url, cancellationToken).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();

            var content = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            return JsonSerializer.Deserialize<ConferenceDetail>(content);
        }

        /// <summary>
        /// Ruft Details zu einem Event ab.
        /// </summary>
        /// <param name="eventId">Die ID des Events.</param>
        /// <param name="cancellationToken">Abbruch-Token.</param>
        /// <returns>Details des Events.</returns>
        public async Task<Event> GetEventAsync(string eventId, CancellationToken cancellationToken)
        {
            var url = $"{BaseUrl}/events/{eventId}";
            _logger.LogInformation("Fetching event details from {Url}", url);

            var response = await _httpClient.GetAsync(url, cancellationToken).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();

            var content = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            return JsonSerializer.Deserialize<Event>(content);
        }
    }
}
