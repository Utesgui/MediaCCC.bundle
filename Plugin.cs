using System;
using System.Collections.Generic;
using Jellyfin.Plugin.MediaCCC.Configuration;
using MediaBrowser.Common.Configuration;
using MediaBrowser.Common.Plugins;
using MediaBrowser.Controller.Entities.Movies;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.Plugins;
using MediaBrowser.Model.Providers;
using MediaBrowser.Model.Serialization;
using Microsoft.Extensions.DependencyInjection;

namespace Jellyfin.Plugin.MediaCCC
{
    /// <summary>
    /// MediaCCC Plugin für Jellyfin
    /// </summary>
    public class Plugin : BasePlugin<PluginConfiguration>, IHasWebPages
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="Plugin"/> class.
        /// </summary>
        /// <param name="applicationPaths">Instance of the <see cref="IApplicationPaths"/> interface.</param>
        /// <param name="xmlSerializer">Instance of the <see cref="IXmlSerializer"/> interface.</param>
        public Plugin(IApplicationPaths applicationPaths, IXmlSerializer xmlSerializer)
            : base(applicationPaths, xmlSerializer)
        {
            Instance = this;
        }

        /// <summary>
        /// Gets the current plugin instance.
        /// </summary>
        public static Plugin Instance { get; private set; }

        /// <inheritdoc />
        public override string Name => "MediaCCC";

        /// <inheritdoc />
        public override Guid Id => Guid.Parse("3FDF2113-F56A-46D0-AABB-D5933DF8B3B3");

        /// <inheritdoc />
        public IEnumerable<PluginPageInfo> GetPages()
        {
            return new[]
            {
                new PluginPageInfo
                {
                    Name = "MediaCCC",
                    EmbeddedResourcePath = $"{GetType().Namespace}.Configuration.configPage.html",
                    EnableInMainMenu = true
                }
            };
        }

        /// <inheritdoc />
        public void ConfigureServices(IServiceCollection serviceCollection)
        {
            // Register HttpClient for MediaCccApiClient
            serviceCollection.AddHttpClient<Api.MediaCccApiClient>();

            // Register the Voctoweb API client
            serviceCollection.AddHttpClient<Api.VoctowebApiClient>();

            // Register the metadata providers
            serviceCollection.AddSingleton<IRemoteMetadataProvider<Movie, MovieInfo>, Providers.MediaCccContentProvider>();
            serviceCollection.AddSingleton<IRemoteImageProvider, Providers.MediaCccImageProvider>();
        }
    }
}
