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
    /// MediaCCC API-Client.
    /// </summary>
    public class MediaCccApiClient
    {
        private readonly ILogger<MediaCccApiClient> _logger;
        private readonly HttpClient _httpClient;
        private const string BaseUrl = "https://api.media.ccc.de";

        /// <summary>
        /// Initializes a new instance of the <see cref="MediaCccApiClient"/> class.
        /// </summary>
        /// <param name="logger">Instance of the <see cref="ILogger"/> interface.</param>
        /// <param name="httpClient">Http client.</param>
        public MediaCccApiClient(ILogger<MediaCccApiClient> logger, HttpClient httpClient)
        {
            _logger = logger;
            _httpClient = httpClient;
        }

        /// <summary>
        /// Ruft alle Konferenzen ab.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>Liste der Konferenzen.</returns>
        public async Task<List<Conference>> GetConferencesAsync(CancellationToken cancellationToken)
        {
            try
            {
                var response = await _httpClient.GetAsync($"{BaseUrl}/public/conferences", cancellationToken).ConfigureAwait(false);
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
                var conferences = JsonSerializer.Deserialize<List<Conference>>(content, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                return conferences ?? new List<Conference>();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Fehler beim Abrufen der Konferenzen");
                throw;
            }
        }

        /// <summary>
        /// Ruft alle Events einer Konferenz ab.
        /// </summary>
        /// <param name="conferenceId">ID der Konferenz.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>Liste der Events.</returns>
        public async Task<List<Event>> GetConferenceEventsAsync(string conferenceId, CancellationToken cancellationToken)
        {
            try
            {
                var response = await _httpClient.GetAsync($"{BaseUrl}/public/conferences/{conferenceId}", cancellationToken).ConfigureAwait(false);
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
                var conference = JsonSerializer.Deserialize<ConferenceDetail>(content, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                return conference?.Events ?? new List<Event>();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Fehler beim Abrufen der Events für Konferenz {ConferenceId}", conferenceId);
                throw;
            }
        }

        /// <summary>
        /// Ruft ein bestimmtes Event ab.
        /// </summary>
        /// <param name="eventId">ID des Events.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>Event-Details.</returns>
        public async Task<EventDetail> GetEventAsync(string eventId, CancellationToken cancellationToken)
        {
            try
            {
                var response = await _httpClient.GetAsync($"{BaseUrl}/public/events/{eventId}", cancellationToken).ConfigureAwait(false);
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
                var eventDetail = JsonSerializer.Deserialize<EventDetail>(content, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                return eventDetail;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Fehler beim Abrufen des Events {EventId}", eventId);
                throw;
            }
        }
    }
}
