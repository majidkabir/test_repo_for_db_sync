SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_DeliveryOrder10                                 */
/* Creation Date: 30-SEP-2019                                           */
/* Copyright: LFL                                                       */
/* Written by: Chooi                                                    */
/*                                                                      */
/* Purpose:  WMS-10739 - CN IKEA DN REPORT                              */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_delivery_Order_10                  */
/*                                                                      */
/* Called By: RCM from MBOL, ReportType = 'DELORDER'                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 2020-04-01   WLChooi 1.1   WMS-12748 - Modify column (WL01)          */
/************************************************************************/

CREATE PROC [dbo].[isp_DeliveryOrder10]
      (@c_MBOLKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1, @n_MaxLine INT = 20

   CREATE TABLE #Temp_DOrder10(
      OtherReference  NVARCHAR(30),   --WL01
      IKEAFAC         NVARCHAR(20),
      UserDefine10    NVARCHAR(10),
      PDETQty         INT,
      RefNo           NVARCHAR(20))

   --WL01 START
   CREATE TABLE #Temp_RefNO(
   Pickslipno   NVARCHAR(10),
   RefNo        NVARCHAR(20),
   Qty          INT)

   INSERT INTO #Temp_RefNO
   SELECT PH.Pickheaderkey, PDET.RefNo, PDET.Qty
   FROM MBOL MB (NOLOCK)
   JOIN MBOLDETAIL MD (NOLOCK) ON MB.MBOLKEY = MD.MBOLKEY
   JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = MD.ORDERKEY
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.ORDERKEY = OH.ORDERKEY
   JOIN PICKHEADER PH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
   JOIN PACKDETAIL PDET (NOLOCK) ON PDET.Pickslipno = PH.PickHeaderKey
   WHERE MB.MBOLKEY = @c_MBOLKey

   --SELECT * FROM #Temp_RefNO
   --WL01 END

   IF(@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      INSERT INTO #Temp_DOrder10
      SELECT   ISNULL(MB.OtherReference,'') AS OtherReference   --MB.Mbolkey --WL01
             , LTRIM(RTRIM(ISNULL(CL1.UDF02,''))) + LTRIM(RTRIM(ISNULL(CL1.Code,''))) AS Storename
             , ISNULL(OH.UserDefine10,'')
             , (SELECT SUM(t.Qty) FROM #Temp_RefNO t WHERE t.RefNo = PDET.RefNo) AS PDETQty --WL01
             , PDET.RefNo
      FROM MBOL MB (NOLOCK)
      JOIN MBOLDETAIL MD (NOLOCK) ON MB.MBOLKEY = MD.MBOLKEY
      JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = MD.ORDERKEY
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.ORDERKEY = OH.ORDERKEY
      JOIN PICKHEADER PH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
      JOIN PACKDETAIL PDET (NOLOCK) ON PDET.Pickslipno = PH.PickHeaderKey
      LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.Listname = 'IKEAFAC' AND CL1.Storerkey = OH.Storerkey AND CL1.Short = MB.Facility
      WHERE MB.MBOLKEY = @c_MBOLKey
      GROUP BY ISNULL(MB.OtherReference,'')   --MB.Mbolkey --WL01
             , LTRIM(RTRIM(ISNULL(CL1.UDF02,''))) + LTRIM(RTRIM(ISNULL(CL1.Code,'')))
             , ISNULL(OH.UserDefine10,'')
             , PDET.RefNo
      END

      SELECT *, (Row_Number() OVER (PARTITION BY Mbolkey ORDER BY Mbolkey Asc) - 1) / @n_MaxLine FROM #Temp_DOrder10
      ORDER BY RefNo

      --WL01 START
      IF OBJECT_ID('tempdb..#Temp_RefNO') IS NOT NULL
         DROP TABLE #Temp_RefNO

      IF OBJECT_ID('tempdb..#Temp_DOrder10') IS NOT NULL
         DROP TABLE #Temp_DOrder10
      --WL01 END
END


GO