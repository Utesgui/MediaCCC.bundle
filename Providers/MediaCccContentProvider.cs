using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.MediaCCC.Api;
using Jellyfin.Plugin.MediaCCC.Api.Models;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Entities.Movies;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.Entities;
using MediaBrowser.Model.Providers;
using Jellyfin.Data.Enums;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.MediaCCC.Providers
{
    /// <summary>
    /// Media-Provider für MediaCCC-Inhalte.
    /// </summary>
    public class MediaCccContentProvider : IRemoteMetadataProvider<Movie, MovieInfo>
    {
        private readonly ILogger<MediaCccContentProvider> _logger;
        private readonly MediaCccApiClient _apiClient;
        private readonly ILibraryManager _libraryManager;

        /// <summary>
        /// Initializes a new instance of the <see cref="MediaCccContentProvider"/> class.
        /// </summary>
        /// <param name="logger">Instance of the <see cref="ILogger"/> interface.</param>
        /// <param name="apiClient">Instance of the API client.</param>
        /// <param name="libraryManager">Instance of the <see cref="ILibraryManager"/> interface.</param>
        public MediaCccContentProvider(
            ILogger<MediaCccContentProvider> logger,
            MediaCccApiClient apiClient,
            ILibraryManager libraryManager)
        {
            _logger = logger;
            _apiClient = apiClient;
            _libraryManager = libraryManager;
        }

        /// <inheritdoc />
        public string Name => "MediaCCC";

        /// <inheritdoc />
        public async Task<MetadataResult<Movie>> GetMetadata(MovieInfo info, CancellationToken cancellationToken)
        {
            var result = new MetadataResult<Movie>();

            try
            {
                // Überprüfen, ob die ID im Format "mediaCCC:{guid}" ist
                if (info.ProviderIds.TryGetValue("MediaCCC", out var eventId))
                {
                    var eventDetail = await _apiClient.GetEventAsync(eventId, cancellationToken).ConfigureAwait(false);
                    if (eventDetail != null)
                    {
                        result.Item = new Movie
                        {
                            Name = eventDetail.Title,
                            Overview = eventDetail.Description,
                            OriginalTitle = eventDetail.Title,
                            PremiereDate = eventDetail.Date,
                            ProductionYear = eventDetail.Date.Year,
                            ProviderIds = new Dictionary<string, string> { { "MediaCCC", eventId } }
                        };

                        // Personen hinzufügen
                        if (eventDetail.Persons != null && eventDetail.Persons.Count > 0)
                        {
                            // Create PersonInfo objects for each person
                            result.People = eventDetail.Persons.Select(p => new PersonInfo
                            {
                                Name = p,
                                Type = PersonKind.Director,
                                Role = "Speaker"
                            }).ToList();
                        }

                        // Tags hinzufügen
                        if (eventDetail.Tags != null && eventDetail.Tags.Count > 0)
                        {
                            result.Item.Tags = eventDetail.Tags.ToArray();
                        }

                        result.HasMetadata = true;
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Fehler beim Abrufen der Metadaten für {Name}", info.Name);
            }

            return result;
        }

        /// <inheritdoc />
        public async Task<IEnumerable<RemoteSearchResult>> GetSearchResults(MovieInfo searchInfo, CancellationToken cancellationToken)
        {
            var results = new List<RemoteSearchResult>();

            try
            {
                if (searchInfo.ProviderIds.TryGetValue("MediaCCC", out var eventId))
                {
                    // Direkte Suche nach ID
                    var eventDetail = await _apiClient.GetEventAsync(eventId, cancellationToken).ConfigureAwait(false);
                    if (eventDetail != null)
                    {
                        results.Add(new RemoteSearchResult
                        {
                            Name = eventDetail.Title,
                            Overview = eventDetail.Description,
                            ProductionYear = eventDetail.Date.Year,
                            ProviderIds = new Dictionary<string, string> { { "MediaCCC", eventId } },
                            ImageUrl = eventDetail.PosterUrl ?? eventDetail.ThumbUrl
                        });
                    }
                }
                else
                {
                    // Suche nach Titel in allen verfügbaren Konferenzen
                    var conferences = await _apiClient.GetConferencesAsync(cancellationToken).ConfigureAwait(false);
                    
                    foreach (var conference in conferences.Take(Plugin.Instance.Configuration.MaxItems / 10))
                    {
                        var events = await _apiClient.GetConferenceEventsAsync(conference.Acronym, cancellationToken)
                            .ConfigureAwait(false);
                        
                        var matchingEvents = events
                            .Where(e => e.Title.Contains(searchInfo.Name, StringComparison.OrdinalIgnoreCase))
                            .Take(5);
                            
                        foreach (var evt in matchingEvents)
                        {
                            results.Add(new RemoteSearchResult
                            {
                                Name = evt.Title,
                                Overview = evt.Description,
                                ProductionYear = evt.Date.Year,
                                ProviderIds = new Dictionary<string, string> { { "MediaCCC", evt.Guid } },
                                ImageUrl = evt.PosterUrl ?? evt.ThumbUrl
                            });
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Fehler bei der Suche nach {SearchInfo}", searchInfo.Name);
            }

            return results;
        }

        /// <inheritdoc />
        public Task<HttpResponseMessage> GetImageResponse(string url, CancellationToken cancellationToken)
        {
            _logger.LogWarning("GetImageResponse should not be called on ContentProvider");
            throw new NotImplementedException("Die Bildverarbeitung wird vom ImageProvider übernommen");
        }
    }
}
