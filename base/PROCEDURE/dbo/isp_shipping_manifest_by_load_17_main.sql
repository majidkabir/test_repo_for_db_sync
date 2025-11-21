SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipping_manifest_by_load_17_main               */
/* Creation Date: 2021-08-09                                             */
/* Copyright: IDS                                                        */
/* Written by: Mingle(copy from isp_shipping_manifest_by_load_12_main    */
/*                                                                       */
/* Purpose:WMS-17652 - r_shipping_manifest_by_load_17 (Main DW)          */
/*                                                                       */
/* Called By: r_shipping_manifest_by_load_17                             */
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
CREATE PROC [dbo].[isp_shipping_manifest_by_load_17_main]
         (  @c_loadkey    NVARCHAR(10),
            @c_Orderkey   NVARCHAR(10) = ''
         )
      
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_storerkey       NVARCHAR(10)
          ,@n_NoOfLine        INT
          ,@c_getstorerkey    NVARCHAR(10)
          ,@c_getLoadkey      NVARCHAR(20)
          ,@c_getOrderkey     NVARCHAR(20)
          ,@c_getExtOrderkey  NVARCHAR(20)
          ,@n_MaxLineno       INT = 13
          ,@n_MaxRec          INT
          ,@n_CurrentRec      INT

  CREATE TABLE #TMP_LoadOH17(
          rowid           int identity(1,1),
          storerkey       NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          Orderkey        NVARCHAR(10) NULL,
          ExtOrdKey       NVARCHAR(50) NULL,
          RPTTYPE         NVARCHAR(1)  NULL,
          Notes1          NVARCHAR(100) NULL,
          Notes2          NVARCHAR(100) NULL,
          Address1        NVARCHAR(100) NULL,
          Phone1          NVARCHAR(20) NULL,
          Fax1            NVARCHAR(50) NULL,
          B_company       NVARCHAR(50) NULL
          )           
   

   IF @c_Orderkey = NULL SET @c_Orderkey = ''   
   
  -- SET @n_NoOfLine = 6
   
   SELECT TOP 1 @c_storerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   WHERE Loadkey = @c_loadkey OR orderkey =  @c_loadkey
   
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND @c_Orderkey <> '')
   BEGIN
      IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND Orderkey = @c_Orderkey)
      BEGIN
         INSERT INTO #TMP_LoadOH17 (storerkey, loadkey, Orderkey,ExtOrdKey,RPTTYPE)  
         SELECT DISTINCT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey,
                CASE WHEN MAX(OD.lottable01)='0501' THEN '2' ELSE '1' END as RPTTYPE
         FROM ORDERS OH (NOLOCK)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey 
         JOIN STORER S WITH (NOLOCK) ON S.StorerKey = OH.StorerKey           
         WHERE OH.LoadKey = @c_loadkey AND OH.Orderkey = @c_Orderkey
         GROUP BY OH.LoadKey,oh.OrderKey,oh.ExternOrderKey                        
      END
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND @c_Orderkey = '') 
   BEGIN
      INSERT INTO #TMP_LoadOH17 (storerkey, loadkey, Orderkey,ExtOrdKey,RPTTYPE)  
      SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey,
             CASE WHEN MAX(OD.lottable01)='0501' THEN '2' ELSE '1' END as RPTTYPE
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
      JOIN STORER S WITH (NOLOCK) ON S.StorerKey = OH.StorerKey            
      WHERE OH.LoadKey = @c_loadkey
      GROUP BY OH.LoadKey,oh.OrderKey,oh.ExternOrderKey                         
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_loadkey AND @c_Orderkey = '') 
   BEGIN
      INSERT INTO #TMP_LoadOH17 (storerkey, loadkey, Orderkey,ExtOrdKey,RPTTYPE)  
      SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey,
             CASE WHEN MAX(OD.lottable01)='0501' THEN '2' ELSE '1' END as RPTTYPE
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
      JOIN STORER S WITH (NOLOCK) ON S.StorerKey = OH.StorerKey            
      WHERE OH.orderkey = @c_loadkey 
      GROUP BY OH.LoadKey,oh.OrderKey,oh.ExternOrderKey                        
   END

   SELECT Loadkey, Orderkey, ExtOrdKey,RPTTYPE,Notes1,Notes2,Address1,Phone1,Fax1,B_Company        
   FROM #TMP_LoadOH17
   ORDER BY ExtOrdKey 
   
QUIT_SP:
   
END

GO