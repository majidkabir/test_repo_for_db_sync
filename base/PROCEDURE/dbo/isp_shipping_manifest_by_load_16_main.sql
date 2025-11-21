SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_shipping_manifest_by_load_16_main               */
/* Creation Date: 2020-04-14                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:WMS-12761 [CN] SUMEI_POD_CR                                   */
/*                                                                       */
/* Called By: r_shipping_manifest_by_load_16                             */
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
CREATE PROC [dbo].[isp_shipping_manifest_by_load_16_main]
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
          ,@c_getExtOrderkey  NVARCHAR(50)
          ,@n_MaxLineno       INT = 13
          ,@n_MaxRec          INT
          ,@n_CurrentRec      INT

  CREATE TABLE #TMP_LoadOH16(
          rowid           int identity(1,1),
          storerkey       NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          Orderkey        NVARCHAR(10) NULL,
          ExtOrdKey       NVARCHAR(50) NULL)           
   

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
         INSERT INTO #TMP_LoadOH16 (storerkey, loadkey, Orderkey,ExtOrdKey)
         SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey
         FROM ORDERS OH (NOLOCK)
         WHERE LoadKey = @c_loadkey AND Orderkey = @c_Orderkey
      END
   END
   --WL01 End
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey AND @c_Orderkey = '') --WL01
   BEGIN
      INSERT INTO #TMP_LoadOH16 (storerkey, loadkey, Orderkey,ExtOrdKey)
      SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey
      FROM ORDERS OH (NOLOCK)
      WHERE LoadKey = @c_loadkey
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_loadkey AND @c_Orderkey = '') --WL01
   BEGIN
      INSERT INTO #TMP_LoadOH16 (storerkey, loadkey, Orderkey,ExtOrdKey)
      SELECT @c_storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey
      FROM ORDERS OH (NOLOCK)
      WHERE orderkey = @c_loadkey 
   END

   SELECT Loadkey, Orderkey, ExtOrdKey
   FROM #TMP_LoadOH16
   ORDER BY ExtOrdKey 
    
QUIT_SP:
    
END


GO