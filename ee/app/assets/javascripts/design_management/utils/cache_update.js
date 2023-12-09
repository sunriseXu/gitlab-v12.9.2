import createFlash from '~/flash';
import { extractCurrentDiscussion, extractDesign } from './design_management_utils';
import {
  ADD_IMAGE_DIFF_NOTE_ERROR,
  UPDATE_IMAGE_DIFF_NOTE_ERROR,
  ADD_DISCUSSION_COMMENT_ERROR,
  UPLOAD_DESIGN_ERROR,
  designDeletionError,
} from './error_messages';

const deleteDesignsFromStore = (store, query, selectedDesigns) => {
  const data = store.readQuery(query);

  const changedDesigns = data.project.issue.designCollection.designs.edges.filter(
    ({ node }) => !selectedDesigns.includes(node.filename),
  );
  data.project.issue.designCollection.designs.edges = [...changedDesigns];

  store.writeQuery({
    ...query,
    data,
  });
};

/**
 * Adds a new version of designs to store
 *
 * @param {Object} store
 * @param {Object} query
 * @param {Object} version
 */
const addNewVersionToStore = (store, query, version) => {
  if (!version) return;

  const data = store.readQuery(query);
  const newEdge = { node: version, __typename: 'DesignVersionEdge' };

  data.project.issue.designCollection.versions.edges = [
    newEdge,
    ...data.project.issue.designCollection.versions.edges,
  ];

  store.writeQuery({
    ...query,
    data,
  });
};

const addDiscussionCommentToStore = (store, createNote, query, queryVariables, discussionId) => {
  const data = store.readQuery({
    query,
    variables: queryVariables,
  });

  const design = extractDesign(data);
  const currentDiscussion = extractCurrentDiscussion(design.discussions, discussionId);
  currentDiscussion.node.notes.edges = [
    ...currentDiscussion.node.notes.edges,
    {
      __typename: 'NoteEdge',
      node: createNote.note,
    },
  ];

  design.notesCount += 1;
  if (
    !design.issue.participants.edges.some(
      participant => participant.node.username === createNote.note.author.username,
    )
  ) {
    design.issue.participants.edges = [
      ...design.issue.participants.edges,
      {
        __typename: 'UserEdge',
        node: {
          // eslint-disable-next-line @gitlab/i18n/no-non-i18n-strings
          __typename: 'User',
          ...createNote.note.author,
        },
      },
    ];
  }
  store.writeQuery({
    query,
    variables: queryVariables,
    data: {
      ...data,
      design: {
        ...design,
      },
    },
  });
};

const addImageDiffNoteToStore = (store, createImageDiffNote, query, variables) => {
  const data = store.readQuery({
    query,
    variables,
  });
  const newDiscussion = {
    __typename: 'DiscussionEdge',
    node: {
      // False positive i18n lint: https://gitlab.com/gitlab-org/frontend/eslint-plugin-i18n/issues/26
      // eslint-disable-next-line @gitlab/i18n/no-non-i18n-strings
      __typename: 'Discussion',
      id: createImageDiffNote.note.discussion.id,
      replyId: createImageDiffNote.note.discussion.replyId,
      notes: {
        __typename: 'NoteConnection',
        edges: [
          {
            __typename: 'NoteEdge',
            node: createImageDiffNote.note,
          },
        ],
      },
    },
  };
  const design = extractDesign(data);
  const notesCount = design.notesCount + 1;
  design.discussions.edges = [...design.discussions.edges, newDiscussion];
  if (
    !design.issue.participants.edges.some(
      participant => participant.node.username === createImageDiffNote.note.author.username,
    )
  ) {
    design.issue.participants.edges = [
      ...design.issue.participants.edges,
      {
        __typename: 'UserEdge',
        node: {
          // eslint-disable-next-line @gitlab/i18n/no-non-i18n-strings
          __typename: 'User',
          ...createImageDiffNote.note.author,
        },
      },
    ];
  }
  store.writeQuery({
    query,
    variables,
    data: {
      ...data,
      design: {
        ...design,
        notesCount,
      },
    },
  });
};

const updateImageDiffNoteInStore = (store, updateImageDiffNote, query, variables) => {
  const data = store.readQuery({
    query,
    variables,
  });

  const design = extractDesign(data);
  const discussion = extractCurrentDiscussion(
    design.discussions,
    updateImageDiffNote.note.discussion.id,
  );

  discussion.node = {
    ...discussion.node,
    notes: {
      ...discussion.node.notes,
      edges: [
        // the first note is original discussion, and includes the pin `position`
        {
          __typename: 'NoteEdge',
          node: updateImageDiffNote.note,
        },
        ...discussion.node.notes.edges.slice(1),
      ],
    },
  };

  store.writeQuery({
    query,
    variables,
    data: {
      ...data,
      design,
    },
  });
};

const addNewDesignToStore = (store, designManagementUpload, query) => {
  const data = store.readQuery(query);

  const newDesigns = data.project.issue.designCollection.designs.edges.reduce((acc, design) => {
    if (!acc.find(d => d.filename === design.node.filename)) {
      acc.push(design.node);
    }

    return acc;
  }, designManagementUpload.designs);

  let newVersionNode;
  const findNewVersions = designManagementUpload.designs.find(design => design.versions);

  if (findNewVersions) {
    const findNewVersionsEdges = findNewVersions.versions.edges;

    if (findNewVersionsEdges && findNewVersionsEdges.length) {
      newVersionNode = [findNewVersionsEdges[0]];
    }
  }

  const newVersions = [
    ...(newVersionNode || []),
    ...data.project.issue.designCollection.versions.edges,
  ];

  const updatedDesigns = {
    __typename: 'DesignCollection',
    designs: {
      __typename: 'DesignConnection',
      edges: newDesigns.map(design => ({
        __typename: 'DesignEdge',
        node: design,
      })),
    },
    versions: {
      __typename: 'DesignVersionConnection',
      edges: newVersions,
    },
  };

  data.project.issue.designCollection = updatedDesigns;

  store.writeQuery({
    ...query,
    data,
  });
};

const onError = (data, message) => {
  createFlash(message);
  throw new Error(data.errors);
};

const hasErrors = ({ errors = [] }) => errors?.length;

/**
 * Updates a store after design deletion
 *
 * @param {Object} store
 * @param {Object} data
 * @param {Object} query
 * @param {Array} designs
 */
export const updateStoreAfterDesignsDelete = (store, data, query, designs) => {
  if (hasErrors(data)) {
    onError(data, designDeletionError({ singular: designs.length === 1 }));
  } else {
    deleteDesignsFromStore(store, query, designs);
    addNewVersionToStore(store, query, data.version);
  }
};

export const updateStoreAfterAddDiscussionComment = (
  store,
  data,
  query,
  queryVariables,
  discussionId,
) => {
  if (hasErrors(data)) {
    onError(data, ADD_DISCUSSION_COMMENT_ERROR);
  } else {
    addDiscussionCommentToStore(store, data, query, queryVariables, discussionId);
  }
};

export const updateStoreAfterAddImageDiffNote = (store, data, query, queryVariables) => {
  if (hasErrors(data)) {
    onError(data, ADD_IMAGE_DIFF_NOTE_ERROR);
  } else {
    addImageDiffNoteToStore(store, data, query, queryVariables);
  }
};

export const updateStoreAfterUpdateImageDiffNote = (store, data, query, queryVariables) => {
  if (hasErrors(data)) {
    onError(data, UPDATE_IMAGE_DIFF_NOTE_ERROR);
  } else {
    updateImageDiffNoteInStore(store, data, query, queryVariables);
  }
};

export const updateStoreAfterUploadDesign = (store, data, query) => {
  if (hasErrors(data)) {
    onError(data, UPLOAD_DESIGN_ERROR);
  } else {
    addNewDesignToStore(store, data, query);
  }
};
