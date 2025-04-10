using System;
using System.Collections.Generic;
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
    /// Bild-Provider für Voctoweb-Inhalte.
    /// </summary>
    public class VoctowebImageProvider : IRemoteImageProvider
    {
        private readonly ILogger<VoctowebImageProvider> _logger;
        private readonly VoctowebApiClient _apiClient;

        /// <summary>
        /// Initializes a new instance of the <see cref="VoctowebImageProvider"/> class.
        /// </summary>
        /// <param name="logger">Logger-Instanz.</param>
        /// <param name="apiClient">API-Client-Instanz.</param>
        public VoctowebImageProvider(ILogger<VoctowebImageProvider> logger, VoctowebApiClient apiClient)
        {
            _logger = logger;
            _apiClient = apiClient;
        }

        /// <inheritdoc />
        public string Name => "Voctoweb";

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

            if (item.ProviderIds.TryGetValue("Voctoweb", out var eventId))
            {
                try
                {
                    var eventDetail = await _apiClient.GetEventAsync(eventId, cancellationToken).ConfigureAwait(false);
                    if (eventDetail != null && !string.IsNullOrEmpty(eventDetail.PosterUrl))
                    {
                        images.Add(new RemoteImageInfo
                        {
                            Url = eventDetail.PosterUrl,
                            Type = ImageType.Primary
                        });
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error fetching images for event ID {EventId}", eventId);
                }
            }

            return images;
        }

        /// <inheritdoc />
        public async Task<HttpResponseMessage> GetImageResponse(string url, CancellationToken cancellationToken)
        {
            var httpClient = new HttpClient();
            return await httpClient.GetAsync(url, cancellationToken).ConfigureAwait(false);
        }
    }
}
