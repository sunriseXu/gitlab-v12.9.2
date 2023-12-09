import { sprintf, s__ } from '~/locale';

// Securely open external links in a new tab.
function getLinkStartTag(url) {
  return `<a href="${url}" target="_blank" rel="noopener noreferrer">`;
}

// Add in the external link icon at the end of every link.
const linkEndTag = '<i class="fa fa-external-link" aria-hidden="true"></i></a>';

export default {
  computed: {
    sastPopover() {
      return {
        title: s__(
          'ciReport|Static Application Security Testing (SAST) detects known vulnerabilities in your source code.',
        ),
        content: sprintf(
          s__('ciReport|%{linkStartTag}Learn more about SAST %{linkEndTag}'),
          {
            linkStartTag: getLinkStartTag(this.sastHelpPath),
            linkEndTag,
          },
          false,
        ),
      };
    },
    containerScanningPopover() {
      return {
        title: s__(
          'ciReport|Container scanning detects known vulnerabilities in your docker images.',
        ),
        content: sprintf(
          s__('ciReport|%{linkStartTag}Learn more about Container Scanning %{linkEndTag}'),
          {
            linkStartTag: getLinkStartTag(this.containerScanningHelpPath),
            linkEndTag,
          },
          false,
        ),
      };
    },
    dastPopover() {
      return {
        title: s__(
          'ciReport|Dynamic Application Security Testing (DAST) detects known vulnerabilities in your web application.',
        ),
        content: sprintf(
          s__('ciReport|%{linkStartTag}Learn more about DAST %{linkEndTag}'),
          {
            linkStartTag: getLinkStartTag(this.dastHelpPath),
            linkEndTag,
          },
          false,
        ),
      };
    },
    dependencyScanningPopover() {
      return {
        title: s__(
          "ciReport|Dependency Scanning detects known vulnerabilities in your source code's dependencies.",
        ),
        content: sprintf(
          s__('ciReport|%{linkStartTag}Learn more about Dependency Scanning %{linkEndTag}'),
          {
            linkStartTag: getLinkStartTag(this.dependencyScanningHelpPath),
            linkEndTag,
          },
          false,
        ),
      };
    },
  },
};
