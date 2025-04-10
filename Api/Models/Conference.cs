using System;
using System.Text.Json.Serialization;

namespace Jellyfin.Plugin.MediaCCC.Api.Models
{
    /// <summary>
    /// Repräsentiert eine Konferenz.
    /// </summary>
    public class Conference
    {
        /// <summary>
        /// Gets or sets the acronym.
        /// </summary>
        [JsonPropertyName("acronym")]
        public string Acronym { get; set; }

        /// <summary>
        /// Gets or sets the aspect ratio.
        /// </summary>
        [JsonPropertyName("aspect_ratio")]
        public string AspectRatio { get; set; }

        /// <summary>
        /// Gets or sets the title.
        /// </summary>
        [JsonPropertyName("title")]
        public string Title { get; set; }

        /// <summary>
        /// Gets or sets the start date.
        /// </summary>
        [JsonPropertyName("start")]
        public DateTime Start { get; set; }

        /// <summary>
        /// Gets or sets the end date.
        /// </summary>
        [JsonPropertyName("end")]
        public DateTime End { get; set; }

        /// <summary>
        /// Gets or sets the URL.
        /// </summary>
        [JsonPropertyName("url")]
        public string Url { get; set; }

        /// <summary>
        /// Gets or sets the webgen location.
        /// </summary>
        [JsonPropertyName("webgen_location")]
        public string WebgenLocation { get; set; }

        /// <summary>
        /// Gets or sets the logo URL.
        /// </summary>
        [JsonPropertyName("logo_url")]
        public string LogoUrl { get; set; }

        /// <summary>
        /// Gets or sets the images.
        /// </summary>
        [JsonPropertyName("images")]
        public ConferenceImages Images { get; set; }
    }

    /// <summary>
    /// Repräsentiert die Bilder einer Konferenz.
    /// </summary>
    public class ConferenceImages
    {
        /// <summary>
        /// Gets or sets the logo URL.
        /// </summary>
        [JsonPropertyName("logo_url")]
        public string LogoUrl { get; set; }

        /// <summary>
        /// Gets or sets the thumbnail URL.
        /// </summary>
        [JsonPropertyName("thumbnail")]
        public string Thumbnail { get; set; }
    }
}
