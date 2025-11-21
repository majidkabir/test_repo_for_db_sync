SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_ConsoPickList30                                */  
/* Creation Date:  04-Aug-2011                                          */  
/* Copyright: IDS                                                       */  
/* Written by:  YTWan                                                   */  
/*                                                                      */  
/* Purpose: SOS#222301. HK-Maxim Consolidated Picklist                  */  
/*                                                                      */  
/* Input Parameters:  @c_Loadkey  - (LoadKey)                           */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  Report                                               */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:  r_dw_consolidated_pick30                                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ConsoPickList30]
            (@c_LoadKey NVARCHAR(10))  
AS  
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTranCnt   INT  
         , @n_continue       INT
         , @n_err            INT 
         , @b_Success        INT
         , @c_errmsg         NVARCHAR(255)
         , @c_PickHeaderKey  NVARCHAR(10)
         , @c_PrintedFlag    NVARCHAR(1)

   SET @n_StartTranCnt  = @@TRANCOUNT  
   SET @n_Continue      = 1 
   SET @n_err           = 0
   SET @b_Success       = 1
   SET @c_errmsg        = ''
   SET @c_PickHeaderKey = ''
   SET @c_PrintedFlag   = 'N'

   /* Start Modification */ 
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order  

   IF NOT EXISTS(
                 SELECT PickHeaderKey
                 FROM   PICKHEADER WITH (NOLOCK)
                 WHERE  ExternOrderKey = @c_Loadkey
                 AND    Zone = '7'
                )
   BEGIN
      SET @b_success = 0 

      EXECUTE nspg_GetKey 
            'PICKSLIP'
          , 9
          , @c_PickHeaderKey  OUTPUT
          , @b_success        OUTPUT
          , @n_err            OUTPUT
          , @c_errmsg         OUTPUT  

      IF @b_success<>1
      BEGIN
         SET @n_continue = 3
         GOTO QUIT
      END  
        
      SET @c_PickHeaderKey = 'P'+@c_PickHeaderKey  

      INSERT INTO PICKHEADER
        (PickHeaderKey ,ExternOrderKey,PickType,Zone)
      VALUES
        (@c_PickHeaderKey,@c_Loadkey,'1','7')  

      SET @n_err = @@ERROR  

      IF @n_err<>0
      BEGIN
         SET @n_continue = 3  
         SET @n_err = 63501  
         SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                       + ': Insert Into PICKHEADER Failed. (isp_ConsoPickList30)'
         GOTO QUIT
      END
   END
   ELSE
   BEGIN
      SELECT @c_PickHeaderKey = PickHeaderKey
      FROM   PickHeader WITH (NOLOCK)
      WHERE  ExternOrderKey = @c_Loadkey
      AND    Zone = '7'

      SET @c_PrintedFlag = 'Y'
   END  

   IF ISNULL(RTRIM(@c_PickHeaderKey) ,'')=''
   BEGIN
      SET @n_continue = 3  
      SET @n_err = 63502  
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) 
                   + ': Get LoadKey Failed. (isp_ConsoPickList30)'
      GOTO QUIT
   END  
    

   SELECT ISNULL(RTRIM(PickHeader.PickHeaderKey),'')
        , @c_PrintedFlag
        , ISNULL(RTRIM(LoadPlan.LoadKey),'')
        , LoadPlan.LPUserdefDate01
        , ISNULL(RTRIM(LoadPlan.Route),'')
        , ISNULL(RTRIM(LoadPlan.TrfRoom),'')
        , ISNULL(RTRIM(PickDetail.Storerkey),'')
        , ISNULL(RTRIM(Storer.Company),'')
        , ISNULL(RTRIM(PickDetail.Sku),'')
        , ISNULL(RTRIM(PickDetail.Loc),'')
        , ISNULL(PickDetail.Qty,0)
        , ISNULL(RTRIM(SKU.Descr),'')
        , ISNULL(RTRIM(SKU.AltSku),'')
        , ISNULL(RTRIM(SKU.ManufacturerSKU),'')
        , ISNULL(SKU.StdCube,0.0) 
        , ISNULL(SKU.StdGrossWgt,0.0) 
        , ISNULL(PACK.CaseCnt,0.0) 
        , ISNULL(PACK.InnerPack,0.0) 
        , CASE IsDate(LotAttribute.Lottable01) WHEN 1 THEN CONVERT( Datetime, LotAttribute.Lottable01)
                                               ELSE NULL
                                               END
        , ISNULL(RTRIM(LotAttribute.Lottable02),'')
        , ISNULL(RTRIM(LotAttribute.Lottable03),'')
        , ISNULL(LotAttribute.Lottable04,'01/01/1900')
        , ISNULL(RTRIM(L.PutawayZone),'')
        , ISNULL(RTRIM(Z.Descr),'')
        , ISNULL(RTRIM(PACK.PackUOM1),'')
        , ISNULL(RTRIM(PACK.PackUOM2),'')
        , ISNULL(RTRIM(PACK.PackUOM3),'')
   FROM  PickHeader WITH (NOLOCK)
   INNER JOIN LoadPlan WITH (NOLOCK)
    ON  (LoadPlan.LoadKey=PICKHEADER.ExternOrderKey)
   INNER JOIN LoadPlanDetail WITH (NOLOCK)
    ON  (LoadPlanDetail.LoadKey=LoadPlan.LoadKey)
   INNER JOIN PickDetail WITH (NOLOCK)
    ON  (PickDetail.OrderKey=LoadPlanDetail.OrderKey)
   INNER JOIN Storer WITH (NOLOCK)
    ON  (Storer.Storerkey=PickDetail.Storerkey)
   INNER JOIN SKU WITH (NOLOCK)
    ON  (SKU.StorerKey=PickDetail.Storerkey)
   AND   (SKU.Sku=PickDetail.Sku)
   INNER JOIN PACK WITH (NOLOCK)
    ON  (PACK.PackKey=SKU.Packkey)
   INNER JOIN LotAttribute WITH (NOLOCK)
    ON  (LotAttribute.LOT=PickDetail.LOT)
   INNER JOIN LOC L WITH (NOLOCK)
    ON  (L.Loc = PickDetail.Loc)
   INNER JOIN PutawayZone Z WITH (NOLOCK)
    ON  (Z.PutawayZone = L.PutawayZone)
   WHERE  PickHeader.PickHeaderKey = @c_PickHeaderKey
   AND    PickDetail.QTY>0 
   ORDER BY ISNULL(RTRIM(LoadPlan.Loadkey),'')
          , ISNULL(RTRIM(L.PutawayZone),'')
          , ISNULL(RTRIM(PickDetail.Loc),'')
          , ISNULL(RTRIM(PickDetail.Sku),'')
          , ISNULL(RTRIM(LotAttribute.Lottable01),'')
          , ISNULL(RTRIM(LotAttribute.Lottable02),'')
          , ISNULL(LotAttribute.Lottable04,'01/01/1900')
          , ISNULL(RTRIM(LotAttribute.Lottable03),'')

   QUIT:
   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ConsoPickList30' 
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1  
      WHILE @@TRANCOUNT>@n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END 
      RETURN
   END
END /* main procedure */  

GO