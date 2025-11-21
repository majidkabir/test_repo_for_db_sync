SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* STORE PROCEDURE: nsp_CheckMissingPalletise_ADIDAS                    */
/* CREATION DATE  : 13-July-2021                                        */
/* WRITTEN BY     : LZG                                                 */
/*                                                                      */
/* PURPOSE: Check for ADIDAS orders with stock in overflow location     */
/*                                                                      */
/* UPDATES:                                                             */
/*                                                                      */
/* DATE     AUTHOR   VER.  PURPOSES                                     */
/*                                                                      */
/************************************************************************/
CREATE PROCEDURE [dbo].[nsp_CheckMissingPalletise_ADIDAS]
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   SELECT P.PALLETKEY AS COLUMN_1,
    AVG(SCANNEDP.SCANNEDCOUNT) AS COLUMN_2
    ,CASE WHEN PD.PALLETKEY IS NULL THEN O.ORDERKEY END AS COLUMN_3,
    CASE WHEN PD.PALLETKEY IS NULL THEN O.EXTERNORDERKEY END AS COLUMN_4,
    O.STATUS AS COLUMN_5,
    CASE WHEN PD.PALLETKEY IS NULL THEN CT.LABELNO END AS COLUMN_6,
    CASE WHEN PD.PALLETKEY IS NULL THEN CT.TRACKINGNO END AS COLUMN_7, '' AS COLUMN_8, '' AS COLUMN_9, '' AS COLUMN_10
    FROM AUWMS..PALLET P (NOLOCK)
    JOIN AUWMS..MBOL M (NOLOCK) ON (M.ExternMbolKey = P.PalletKey)
    JOIN AUWMS..ORDERS O (NOLOCK) ON (O.MBOLKey = M.MbolKey)
    JOIN AUWMS..CartonTrack CT (NOLOCK) ON (O.TrackingNo = CT.UDF03 AND O.StorerKey = CT.KeyName AND O.ShipperKey = CT.CARRIERNAME)
    JOIN (SELECT PALLETKEY,COUNT(CASEID) AS SCANNEDCOUNT FROM AUWMS..PALLETDETAIL (NOLOCK)
          WHERE StorerKey = 'ADIDAS' AND Status < '9' GROUP BY PALLETKEY)
          AS SCANNEDP ON (P.PalletKey = SCANNEDP.PalletKey)
    LEFT JOIN AUWMS..PALLETDETAIL PD (NOLOCK) ON
    (CT.LabelNo = PD.CaseId AND CT.TrackingNo = PD.UserDefine02 AND O.OrderKey = PD.UserDefine01)
    WHERE P.StorerKey = 'ADIDAS' AND P.Status < '9'
    GROUP BY P.PALLETKEY,CASE WHEN PD.PALLETKEY IS NULL THEN O.ORDERKEY END,
             CASE WHEN PD.PALLETKEY IS NULL THEN O.EXTERNORDERKEY END,
             O.STATUS, CASE WHEN PD.PALLETKEY IS NULL THEN CT.LABELNO END,
             CASE WHEN PD.PALLETKEY IS NULL THEN CT.TRACKINGNO END
    ORDER BY P.PALLETKEY


QUIT:

END

GO