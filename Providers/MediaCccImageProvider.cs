using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Jellyfin.Plugin.MediaCCC.Api;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Entities.Movies;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.Entities;
using MediaBrowser.Model.Providers;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.MediaCCC.Providers
{
    /// <summary>
    /// Media-Bilder-Provider für MediaCCC-Inhalte.
    /// </summary>
    public class MediaCccImageProvider : IRemoteImageProvider
    {
        private readonly ILogger<MediaCccImageProvider> _logger;
        private readonly MediaCccApiClient _apiClient;
        private readonly HttpClient _httpClient;

        /// <summary>
        /// Initializes a new instance of the <see cref="MediaCccImageProvider"/> class.
        /// </summary>
        /// <param name="logger">Instance of the <see cref="ILogger"/> interface.</param>
        /// <param name="apiClient">Instance of the API client.</param>
        /// <param name="httpClient">Instance of HttpClient.</param>
        public MediaCccImageProvider(
            ILogger<MediaCccImageProvider> logger,
            MediaCccApiClient apiClient,
            HttpClient httpClient)
        {
            _logger = logger;
            _apiClient = apiClient;
            _httpClient = httpClient ?? new HttpClient();
        }

        /// <inheritdoc />
        public string Name => "MediaCCC";

        /// <inheritdoc />
        public bool Supports(BaseItem item)
        {
            return item is Movie;
        }

        /// <inheritdoc />
        public IEnumerable<ImageType> GetSupportedImages(BaseItem item)
        {
            return new[] { ImageType.Primary, ImageType.Thumb };
        }

        /// <inheritdoc />
        public async Task<IEnumerable<RemoteImageInfo>> GetImages(BaseItem item, CancellationToken cancellationToken)
        {
            var images = new List<RemoteImageInfo>();

            try
            {
                if (item.ProviderIds.TryGetValue("MediaCCC", out var eventId))
                {
                    var eventDetail = await _apiClient.GetEventAsync(eventId, cancellationToken).ConfigureAwait(false);
                    if (eventDetail != null)
                    {
                        if (!string.IsNullOrEmpty(eventDetail.PosterUrl))
                        {
                            images.Add(new RemoteImageInfo
                            {
                                ProviderName = Name,
                                Url = eventDetail.PosterUrl,
                                Type = ImageType.Primary
                            });
                        }

                        if (!string.IsNullOrEmpty(eventDetail.ThumbUrl))
                        {
                            images.Add(new RemoteImageInfo
                            {
                                ProviderName = Name,
                                Url = eventDetail.ThumbUrl,
                                Type = ImageType.Thumb
                            });
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Fehler beim Abrufen der Bilder für {Name}", item.Name);
            }

            return images;
        }

        /// <inheritdoc />
        public async Task<HttpResponseMessage> GetImageResponse(string url, CancellationToken cancellationToken)
        {
            try
            {
                return await _httpClient.GetAsync(url, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting image response from {Url}", url);
                throw;
            }
        }
    }
}
