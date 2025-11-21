SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* STORE PROCEDURE: nsp_TEMP_CheckCartonstoPalletise_ADIDAS             */
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
CREATE PROCEDURE [dbo].[nsp_TEMP_CheckCartonstoPalletise_ADIDAS]
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   SELECT DISTINCT CT.LABELNO AS COLUMN_1,CT.TRACKINGNO AS COLUMN_2, O.CONSIGNEEKEY AS COLUMN_3,
   O.C_STATE AS COLUMN_4,
   '' AS COLUMN_5,
   '' AS COLUMN_6,
   '' AS COLUMN_7,
   '' AS COLUMN_8,
   '' AS COLUMN_9,
   '' AS COLUMN_10
   FROM CartonTrack CT (NOLOCK) JOIN ORDERS O (NOLOCK) ON (CT.UDF03 = O.TrackingNo AND CT.KeyName = O.StorerKey)
   WHERE O.Status = '5' AND O.OrderKey IN (
   SELECT DISTINCT ORDERDETAILD.ORDERKEY FROM
   (SELECT ORDERKEY,SUM(ORIGINALQTY) AS ORDEREDQTY,SUM(QTYPICKED) AS PICKEDQTY FROM ORDERDETAIL (NOLOCK) WHERE
   STORERKEY = 'ADIDAS' AND ORDERKEY IN (
   SELECT DISTINCT(ORDERKEY) FROM PICKDETAIL (NOLOCK) WHERE Status = '5' AND Storerkey = 'ADIDAS') GROUP BY ORDERKEY) AS ORDERDETAILD
   JOIN (SELECT ORDERKEY,SUM(QTY) AS PICKDETAILQTY FROM PICKDETAIL (NOLOCK) WHERE STORERKEY = 'ADIDAS' AND STATUS = '5' AND
   ORDERKEY IN (SELECT DISTINCT(ORDERKEY) FROM PICKDETAIL (NOLOCK) WHERE Status = '5' AND Storerkey = 'ADIDAS') GROUP BY ORDERKEY)
   AS PICKDETAILD ON (ORDERDETAILD.OrderKey = PICKDETAILD.OrderKey) JOIN (
   SELECT PH.ORDERKEY,SUM(PD.QTY) AS PACKDETAILQTY FROM PACKDETAIL PD (NOLOCK) JOIN PACKHEADER PH (NOLOCK) ON (
   PD.PICKSLIPNO = PH.PICKSLIPNO) WHERE PH.ORDERKEY IN (
   SELECT DISTINCT(ORDERKEY) FROM PICKDETAIL (NOLOCK) WHERE Status = '5' AND Storerkey = 'ADIDAS') GROUP BY PH.ORDERKEY
   ) PACKDETAILD ON (ORDERDETAILD.OrderKey = PACKDETAILD.OrderKey)
   WHERE CAST((ORDEREDQTY + PICKEDQTY + PICKDETAILQTY + PACKDETAILQTY)/4.0 AS FLOAT) = ORDEREDQTY)
  


QUIT:

END

GO