SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc : nsp_WSDT_Status_Monitor                                   */
/* Copyright: LFL                                                          */
/* Written by: Calvin Khor                                                 */
/*                                                                         */
/* Purpose: Monitor WS status                                              */
/*                                                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: Back-end job                                                 */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date              Author         Ver      Purposes                      */
/* 03-Feb-2020       Calvin Khor    1.0      Initial version.              */
/***************************************************************************/

CREATE PROCEDURE [dbo].[nsp_WSDT_Status_Monitor]
AS
BEGIN
    DECLARE @d_StartTime DATETIME = DATEADD(MINUTE, -65, GETDATE());
    DECLARE @d_Other_Status_Adddate DATETIME = '2018-11-01';

    SELECT   T.StorerKey ,
             T.RecordType ,
             T.DataStream ,
             ISNULL(wsc.Descr, c.Descr) AS Descr ,
             T.WSDT_Status ,
             T.RecordNum ,
             T.ErrCode ,
             ISNULL(lkup.Description, '') AS ErrMsg ,
             '' ,
             ''
    FROM     (SELECT   StorerKey ,
                       'ORD' AS RecordType ,
                       DataStream ,
                       WSDT_Status ,
                       ErrCode ,
                       CONVERT(NVARCHAR(10), COUNT(1), 0) AS RecordNum
              FROM     SGDTSITF..WSDT_GENERIC_ORD_HDR (NOLOCK)
              WHERE    StorerKey IN ( SELECT Code FROM SGWMS..CODELKUP (NOLOCK) WHERE LISTNAME = 'WS_MONITOR' AND UDF01 = '1' )
                       AND WSDT_Status <> '5'
                       AND WSDT_Status <> '9'
                       AND DATEDIFF(MINUTE, EditDate, GETDATE()) > 60
                       AND AddDate > @d_Other_Status_Adddate
              GROUP BY StorerKey ,
                       DataStream ,
                       WSDT_Status ,
                       ErrCode
              UNION ALL
              SELECT   StorerKey ,
                       'ASN' AS RecordType ,
                       DataStream ,
                       WSDT_Status ,
                       ErrCode ,
                       CONVERT(NVARCHAR(10), COUNT(1), 0) AS RecordNum
              FROM     SGDTSITF..WSDT_GENERIC_ASN_HDR (NOLOCK)
              WHERE    StorerKey IN ( SELECT Code FROM SGWMS..CODELKUP (NOLOCK) WHERE LISTNAME = 'WS_MONITOR' AND UDF01 = '1' )
                       AND WSDT_Status <> '5'
                       AND WSDT_Status <> '9'
                       AND DATEDIFF(MINUTE, EditDate, GETDATE()) > 60
                       AND AddDate > @d_Other_Status_Adddate
              GROUP BY StorerKey ,
                       DataStream ,
                       WSDT_Status ,
                       ErrCode
              UNION ALL
              SELECT   StorerKey ,
                       'SHP' AS RecordType ,
                       DataStream ,
                       WSDT_Status ,
                       ErrCode ,
                       CONVERT(NVARCHAR(10), COUNT(1), 0) AS RecordNum
              FROM     SGDTSITF..WSDT_GENERIC_SHP_HDR (NOLOCK)
              WHERE    StorerKey IN ( SELECT Code FROM SGWMS..CODELKUP (NOLOCK) WHERE LISTNAME = 'WS_MONITOR' AND UDF01 = '1' )
                       AND WSDT_Status <> '5'
                       AND WSDT_Status <> '9'
                       AND DATEDIFF(MINUTE, EditDate, GETDATE()) > 60
                       AND AddDate > @d_Other_Status_Adddate
              GROUP BY StorerKey ,
                       DataStream ,
                       WSDT_Status ,
                       ErrCode
              UNION ALL
              SELECT   StorerKey ,
                       'REC' AS RecordType ,
                       DataStream ,
                       WSDT_Status ,
                       ErrCode ,
                       CONVERT(NVARCHAR(10), COUNT(1), 0) AS RecordNum
              FROM     SGDTSITF..WSDT_GENERIC_REC_HDR (NOLOCK)
              WHERE    StorerKey IN ( SELECT Code FROM SGWMS..CODELKUP (NOLOCK) WHERE LISTNAME = 'WS_MONITOR' AND UDF01 = '1' )
                       AND WSDT_Status <> '5'
                       AND WSDT_Status <> '9'
                       AND DATEDIFF(MINUTE, EditDate, GETDATE()) > 60
                       AND AddDate > @d_Other_Status_Adddate
              GROUP BY StorerKey ,
                    DataStream ,
                       WSDT_Status ,
                       ErrCode) AS T
             LEFT JOIN SGDTSITF..WS_ITFCONFIG wsc (NOLOCK) ON wsc.DataStream = T.DataStream
             LEFT JOIN SGDTSITF..itfConfig c (NOLOCK) ON c.DataStream = T.DataStream
          LEFT JOIN SGDTSITF..WOL_ITFCONFIG wolc (NOLOCK) ON wolc.DataStream = T.DataStream
             LEFT JOIN SGWMS..CODELKUP lkup (NOLOCK) ON lkup.Code = T.ErrCode
                                                        AND lkup.LISTNAME = 'WS_ERRCODE'
    WHERE    ISNULL(lkup.UDF03, 1) = 1
    ORDER BY T.StorerKey ,
             T.RecordType ,
             T.DataStream ,
             T.WSDT_Status;
END -- Procedure

GO