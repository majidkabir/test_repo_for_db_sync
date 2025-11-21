SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Return_Note01_rdt                               */
/* Creation Date: 2019-05-31                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-9080 VANS Return Note                                    */
/*                                                                       */
/* Called By: r_dw_return_notes01                                        */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/*************************************************************************/

CREATE PROC [dbo].[isp_Return_Note01_rdt]
			(  @c_Orderkey    NVARCHAR(30)
			)           
AS
BEGIN
	SET NOCOUNT ON
	SET ANSI_DEFAULTS OFF  
	SET QUOTED_IDENTIFIER OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1

   CREATE TABLE #Temp_OrdKey36(
   Orderkey     NVARCHAR(10)  )

   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE ORDERKEY = @c_Orderkey)
   BEGIN
      INSERT INTO #Temp_OrdKey36
      VALUES(@c_Orderkey)
   END
   ELSE
   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE ExternOrderkey = @c_Orderkey)
   BEGIN
      INSERT INTO #Temp_OrdKey36
      SELECT DISTINCT ORDERKEY
      FROM ORDERS (NOLOCK) 
      WHERE ExternOrderkey = @c_Orderkey
   END
   ELSE
   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE TrackingNo = @c_Orderkey)
   BEGIN
      INSERT INTO #Temp_OrdKey36
      SELECT DISTINCT ORDERKEY
      FROM ORDERS (NOLOCK) 
      WHERE TrackingNo = @c_Orderkey
   END

   IF NOT EXISTS (SELECT 1 FROM #Temp_OrdKey36)
      GOTO QUIT_SP
   
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT   ISNULL(ORD.C_contact1,'') AS C_Contact1
             , ISNULL(RTRIM(ORD.C_Address2),'') + ' ' + ISNULL(LTRIM(RTRIM(ORD.C_Address3)),'') + ' ' +  ISNULL(LTRIM(RTRIM(ORD.C_Address4)),'') AS C_Addresses
             , ISNULL(ORD.C_Phone1,'') AS C_Phone1
             , REPLACE(CONVERT(NVARCHAR(10),GETDATE(),102),'.','-') AS TodayDate
             , ORD.Externorderkey 
             , ORD.Orderkey
             , ISNULL(OI.EcomOrderID,'') AS EcomOrderID
             , ISNULL(ORD.TrackingNo,'') AS TrackingNo
             , ISNULL(ORD.Notes,'') AS Notes
             , ISNULL(S.Style,'') AS Style
             , ISNULL(S.Color,'') AS Color
             , ISNULL(S.Size,'') AS Size
             , ISNULL(S.Descr,'') AS Descr
             , SUM(OD.QtyPicked + OD.ShippedQty) AS Qty
             , OD.UnitPrice 
             , ISNULL(ST.B_Company,'') AS B_Company
             , ISNULL(RTRIM(ST.B_Address1),'') + ' ' + ISNULL(LTRIM(RTRIM(ST.B_Address2)),'') + ' ' + 
               ISNULL(LTRIM(RTRIM(ST.B_Address3)),'') + ' ' + ISNULL(LTRIM(RTRIM(ST.B_Address4)),'') AS B_Addresses
             , ISNULL(ST.B_Phone1,'') AS B_Phone1
             , ISNULL(S.AltSku,'') AS AltSku
             , ISNULL(ORD.Storerkey,'') AS Storerkey
      FROM ORDERS ORD (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON ORD.Orderkey = OD.Orderkey
      JOIN SKU S (NOLOCK) ON S.SKU = OD.SKU AND S.STORERKEY = OD.STORERKEY
      JOIN #Temp_OrdKey36 T ON T.Orderkey = ORD.Orderkey
      JOIN STORER ST (NOLOCK) ON ST.Storerkey = ORD.Storerkey
      LEFT JOIN ORDERINFO OI (NOLOCK) ON ORD.ORDERKEY = OI.ORDERKEY
      --WHERE ORD.Orderkey = @c_Orderkey
      GROUP BY ISNULL(ORD.C_contact1,'')
             , ISNULL(RTRIM(ORD.C_Address2),'') + ' ' +  ISNULL(LTRIM(RTRIM(ORD.C_Address3)),'') + ' ' +  ISNULL(LTRIM(RTRIM(ORD.C_Address4)),'')
             , ISNULL(ORD.C_Phone1,'')
             , ORD.Externorderkey
             , ORD.Orderkey
             , ISNULL(OI.EcomOrderID,'')
             , ISNULL(ORD.TrackingNo,'')
             , ISNULL(ORD.Notes,'')
             , ISNULL(S.Style,'')
             , ISNULL(S.Color,'')
             , ISNULL(S.Size,'')
             , ISNULL(S.Descr,'')
             , OD.UnitPrice
             , ISNULL(ST.B_Company,'')
             , ISNULL(RTRIM(ST.B_Address1),'') + ' ' + ISNULL(LTRIM(RTRIM(ST.B_Address2)),'') + ' ' + 
               ISNULL(LTRIM(RTRIM(ST.B_Address3)),'') + ' ' + ISNULL(LTRIM(RTRIM(ST.B_Address4)),'')
             , ISNULL(ST.B_Phone1,'')
             , ISNULL(S.AltSku,'')
             , ISNULL(ORD.Storerkey,'')
   END

QUIT_SP:  
END       

GO