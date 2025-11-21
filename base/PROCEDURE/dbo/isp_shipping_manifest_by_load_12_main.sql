SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipping_manifest_by_load_12_main               */
/* Creation Date: 2019-08-21                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:WMS-10175 - r_shipping_manifest_by_load_12 (Main DW)          */
/*                                                                       */
/* Called By: r_shipping_manifest_by_load_12                             */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/*16/10/2019    WLChooi 1.1   Sort by Externorderkey (WL01)              */
/*10/09/2020    CSCHONG 1.2   WMS-14938 add print new report (CS01)      */
/*************************************************************************/
CREATE PROC [dbo].[isp_shipping_manifest_by_load_12_main]
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

  CREATE TABLE #TMP_LoadOH12(
          rowid           int identity(1,1),
          storerkey       NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          Orderkey        NVARCHAR(10) NULL,
          ExtOrdKey       NVARCHAR(50) NULL,
          RPTTYPE         NVARCHAR(1)  NULL)           
   

   IF @c_Orderkey = NULL SET @c_Orderkey = ''   
   
  -- SET @n_NoOfLine = 6
   
   SELECT TOP 1 @c_storerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   WHERE Loadkey = @c_loadkey OR orderkey =  @c_loadkey
   
   --WL01 Start
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND @c_Orderkey <> '')
   BEGIN
      IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND Orderkey = @c_Orderkey)
      BEGIN
         INSERT INTO #TMP_LoadOH12 (storerkey, loadkey, Orderkey,ExtOrdKey,RPTTYPE)  --CS01
         SELECT DISTINCT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey,
                CASE WHEN MAX(OD.lottable01)='0501' THEN '2' ELSE '1' END as RPTTYPE --CS01
         FROM ORDERS OH (NOLOCK)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey            --CS01
         WHERE OH.LoadKey = @c_loadkey AND OH.Orderkey = @c_Orderkey
         GROUP BY OH.LoadKey,oh.OrderKey,oh.ExternOrderKey                         --CS01
      END
   END
   --WL01 End
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND @c_Orderkey = '') --WL01
   BEGIN
      INSERT INTO #TMP_LoadOH12 (storerkey, loadkey, Orderkey,ExtOrdKey,RPTTYPE)  --CS01
      SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey,
             CASE WHEN MAX(OD.lottable01)='0501' THEN '2' ELSE '1' END as RPTTYPE --CS01
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey            --CS01
      WHERE OH.LoadKey = @c_loadkey
      GROUP BY OH.LoadKey,oh.OrderKey,oh.ExternOrderKey                         --CS01
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_loadkey AND @c_Orderkey = '') --WL01
   BEGIN
      INSERT INTO #TMP_LoadOH12 (storerkey, loadkey, Orderkey,ExtOrdKey,RPTTYPE)  --CS01
      SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey,
             CASE WHEN MAX(OD.lottable01)='0501' THEN '2' ELSE '1' END as RPTTYPE --CS01
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey            --CS01
      WHERE OH.orderkey = @c_loadkey 
      GROUP BY OH.LoadKey,oh.OrderKey,oh.ExternOrderKey                         --CS01
   END

   SELECT Loadkey, Orderkey, ExtOrdKey,RPTTYPE         --CS01
   FROM #TMP_LoadOH12
   ORDER BY ExtOrdKey --WL01
    
QUIT_SP:
    
END


GO