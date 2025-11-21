SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Proc : isp_PiecePickList_ord                                  */  
/* Creation Date: 08-Aug-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by:YTWan                                                     */  
/*                                                                      */  
/* Purpose: SOS#222524 - Piece PickSlip by Order - Converse CN          */  
/*        : Copy & Modified from nspPiecePickList                       */  
/*                                                                      */  
/* Input Parameters: loadkeystart, loadkeyend                           */  
/*                                                                      */  
/* Output Parameters: Report                                            */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: r_dw_piecepickslip_byorder                                */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 08-DEC-2011  YTWan    1.1  SOS#231858 - Add City. (Wan01)            */  
/* 09-May-2012  TLTING   1.2  Perfromance tune -                        */
/* 14-Feb-2014  NJOW01   1.3  303108-Add company field                  */ 
/* 05-Oct-2016  CSCHONG  1.4  WMS-393 - Add new field (CS01)            */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_PiecePickList_ord] (  
               @c_Facility       NVARCHAR(5)  
            ,  @c_LoadKeyStart   NVARCHAR(10)  
            ,  @c_LoadKeyEnd     NVARCHAR(10)  )  
 AS  
 BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF     
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE  @n_StartTranCnt  INT   
         ,  @n_Continue      INT   
         ,  @n_Err           INT   
         ,  @b_Success       INT   
         ,  @c_ErrMsg        NVARCHAR(255)   
  
   DECLARE  @c_LoadKey       NVARCHAR(10)   
         ,  @c_Orderkey      NVARCHAR(10)  
         ,  @c_PickHeaderKey NVARCHAR(10)  
  
   SET @n_StartTranCnt  = @@TRANCOUNT  
   SET @n_continue      = 1  
   SET @n_Err           = 0  
   SET @b_Success       = 1  
   SET @c_ErrMsg        = ''  
  
   SET @c_LoadKey       = ''  
   SET @c_Orderkey      = ''  
   SET @c_PickHeaderKey = ''  
  
 /* Start Modification */  
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order  
   
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN
  
   DECLARE CURSOR_SO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT ISNULL(RTRIM(LP.LoadKey),'')  
         ,ISNULL(RTRIM(LPD.OrderKey),'')
     FROM LoadPlan LP WITH (NOLOCK)  
     JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = LP.Loadkey)  
     JOIN PickDetail     PD  WITH (NOLOCK) ON (PD.Orderkey = LPD.Orderkey)  
     JOIN SKUxLOC        SL  WITH (NOLOCK) ON (SL.Storerkey= PD.Storerkey)  
                                           AND(SL.Sku      = PD.Sku)  
                                           AND(SL.Loc      = PD.Loc)  
    WHERE  LP.Facility     =  @c_facility  
      AND  LP.Loadkey      >= @c_loadkeystart  
      AND  LP.Loadkey      <= @c_loadkeyend  
      AND  SL.Locationtype = 'PICK'  
      AND  PD.Status       < '5'  
      AND  PD.Qty > 0  
   ORDER BY ISNULL(RTRIM(LP.LoadKey),'')  
         ,  ISNULL(RTRIM(LPD.OrderKey),'')  
  
   OPEN CURSOR_SO  
  
   FETCH NEXT FROM CURSOR_SO INTO @c_LoadKey  
                                 ,@c_Orderkey  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF NOT EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_LoadKey   
                    AND Orderkey = @c_OrderKey AND Zone = '3')   
      BEGIN  
         SET @b_success = 0  
         BEGIN TRAN
         EXECUTE nspg_GetKey  
                 'PICKSLIP'   
               , 9      
               , @c_PickHeaderKey   OUTPUT   
               , @b_success         OUTPUT   
               , @n_err             OUTPUT   
               , @c_errmsg          OUTPUT  
     
         IF @b_success <> 1  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 63501  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Getting PickSlip #. (isp_PiecePickList_ord)'  
            GOTO QUIT  
         END  
         ELSE 
         BEGIN
            COMMIT TRAN
         END
  
         SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey  
         BEGIN TRAN  
         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, OrderKey, Zone)  
         VALUES (@c_PickHeaderKey, @c_LoadKey, @c_Orderkey, '3')  
            
         SET @n_err = @@ERROR  
     
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 63502  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (isp_PiecePickList_ord)'  
            GOTO QUIT  
         END  
         ELSE 
         BEGIN
            COMMIT TRAN
         END
      END  
      FETCH NEXT FROM CURSOR_SO INTO @c_LoadKey  
                                    ,@c_Orderkey  
   END   
   CLOSE CURSOR_SO  
   DEALLOCATE CURSOR_SO  

   WHILE @@TRANCOUNT < @n_StartTranCnt
      BEGIN TRAN
  
   SELECT ISNULL(RTRIM(LP.LoadKey),'')          AS Loadkey  
         ,ISNULL(RTRIM(PH.PickHeaderKey),'')    AS PickHeaderKey  
         --(Wan01) - START  
         --,ISNULL(RTRIM(LP.Route),'')            AS Route  
         ,CASE WHEN ST.Storerkey IS NULL THEN ISNULL(RTRIM(OH.C_State),'') + ISNULL(RTRIM(OH.C_City),'')  
                                         ELSE ISNULL(RTRIM(ST.State),'') + ISNULL(RTRIM(ST.City),'')  
                                         END    AS City  
         --(Wan01) - END  
         ,ISNULL(LP.AddDate,'1900/01/01')       AS AddDate  
         ,ISNULL(RTRIM(OH.Orderkey),'')         AS Orderkey  
         ,ISNULL(RTRIM(OH.ExternOrderkey),'')   AS ExternOrderkey  
         ,ISNULL(RTRIM(OH.BillTokey),'') + '-'   
         +ISNULL(RTRIM(OH.ConsigneeKey),'')     AS CustomerNo  
         ,ISNULL(TOD.TotalQtyOrdered,0)         AS TotalQtyOrdered  
         ,ISNULL(TPD.TotalQtyInBulk,0)          AS TotalQtyInBulk  
         ,ISNULL(RTRIM(PD.Loc),'')              AS Loc  
         ,ISNULL(RTRIM(S.Style),'')             AS Style  
         ,ISNULL(RTRIM(S.Color),'')             AS Color  
         ,ISNULL(RTRIM(S.Size),'')              AS Size  
         ,ISNULL(SUM(PD.Qty),0)                 AS Qty   
         ,'Pack (' + ISNULL(RTRIM(P.PackUOM3),'')   
         + 'x' + CONVERT(NVARCHAR(10), ISNULL(P.CaseCnt,0)) + ')' AS PackDesc  
         ,ISNULL(P.CaseCnt,0)                   AS CaseCnt  
         ,ISNULL(P.InnerPack,0)                 AS InnerPack  
         ,ISNULL(RTRIM(P.PackUOM3),'')          AS PackUOM3  
         ,ISNULL(RTRIM(LA.Lottable02),'')       AS Lotable02 
			,CASE WHEN ISNULL(ST.Storerkey,'')='' THEN OH.C_Company ELSE ST.Company END AS Company  --NJOW01    
		   ,ISNULL(S1.SUSR2,'')   AS SSUSR2	                                                       --CS01	                                                                                         --       
    FROM LoadPlan       LP  WITH (NOLOCK)   
    JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey       = LP.LoadKey)   
    JOIN Orders         OH  WITH (NOLOCK) ON (OH.Orderkey       = LPD.Orderkey)  
    JOIN PickHeader     PH  WITH (NOLOCK) ON (PH.ExternOrderKey = LP.LoadKey)   
                                          AND(PH.Orderkey       = OH.Orderkey)  
    JOIN PickDetail     PD  WITH (NOLOCK) ON (PD.OrderKey       = OH.OrderKey)   
    JOIN SKUxLOC        SL  WITH (NOLOCK) ON (SL.Storerkey      = PD.StorerKey)   
                                          AND(SL.Sku         = PD.Sku)  
                                          AND(SL.Loc            = PD.Loc)  
    JOIN LotAttribute   LA  WITH (NOLOCK) ON (LA.Lot            = PD.Lot)   
    JOIN SKU            S   WITH (NOLOCK) ON (S.Storerkey       = PD.StorerKey)  
                                          AND(S.Sku             = PD.Sku)  
    JOIN Pack           P   WITH (NOLOCK) ON (P.Packkey         = S.Packkey)  
    JOIN (SELECT ISNULL(RTRIM(OrderKey),'')    AS Orderkey  
               , ISNULL(SUM(OpenQty),0) AS TotalQtyOrdered   
            FROM ORDERDETAIL WITH (NOLOCK)  
          GROUP BY ISNULL(RTRIM(OrderKey),'') ) TOD     
                                          ON (TOD.Orderkey = OH.Orderkey)  
    LEFT JOIN (SELECT ISNULL(RTRIM(LPD.OrderKey),'')    AS Orderkey  
                   ,  ISNULL(SUM(PD.Qty),0) AS TotalQtyInBulk  
                 FROM Loadplan       LP  WITH (NOLOCK)   
                 JOIN LoadplanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = LP.LoadKey)  
                 JOIN PickDetail     PD  WITH (NOLOCK) ON (PD.Orderkey = LPD.Orderkey)  
                 JOIN SKUxLOC        SL  WITH (NOLOCK) ON (SL.Storerkey= PD.Storerkey)  
                                                       AND(SL.Sku      = PD.Sku)  
                                                       AND(SL.Loc      = PD.Loc)  
                WHERE LP.Facility = @c_facility  
                  AND LP.LoadKey >= @c_loadkeystart  
                  AND LP.LoadKey <= @c_loadkeyend  
                  AND SL.LocationType <> 'PICK'   
                  AND SL.LocationType <> 'CASE'   
               GROUP BY ISNULL(RTRIM(LPD.OrderKey),'')) TPD  
                                          ON (TPD.Orderkey = LPD.Orderkey)  
   --(Wan01) - START  
   LEFT JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = ISNULL(RTRIM(OH.BillToKey),'') + ISNULL(RTRIM(OH.ConsigneeKey),''))  
   --(Wan01) - END  
   LEFT JOIN Storer S1 WITH (NOLOCK) ON S1.StorerKey=OH.ConsigneeKey       --(CS01)
   WHERE LP.Facility = @c_facility  
     AND LP.LoadKey >= @c_loadkeystart  
     AND LP.LoadKey <= @c_loadkeyend  
     AND PH.Zone     = '3'  
     AND SL.LocationType = 'PICK'  
     AND PD.STATUS  < '5'  
   GROUP BY ISNULL(RTRIM(LP.LoadKey),'')  
         ,  ISNULL(RTRIM(PH.PickHeaderKey),'')  
         --(Wan01) - START       
         --,  ISNULL(RTRIM(LP.Route),'')  
         ,CASE WHEN ST.Storerkey IS NULL THEN ISNULL(RTRIM(OH.C_State),'') + ISNULL(RTRIM(OH.C_City),'')  
                                         ELSE ISNULL(RTRIM(ST.State),'') + ISNULL(RTRIM(ST.City),'')  
                                         END       
         --(Wan01) - END              
         ,  ISNULL(LP.AddDate,'1900/01/01')          
         ,  ISNULL(RTRIM(OH.Orderkey),'')   
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')    
         ,  ISNULL(RTRIM(OH.BillTokey),'') + '-' + ISNULL(RTRIM(OH.ConsigneeKey),'')        
         ,  ISNULL(TOD.TotalQtyOrdered,0)   
         ,  ISNULL(TPD.TotalQtyInBulk,0)             
         ,  ISNULL(RTRIM(PD.Loc),'')                 
         ,  ISNULL(RTRIM(S.Style),'')                
         ,  ISNULL(RTRIM(S.Color),'')               
         ,  ISNULL(RTRIM(S.Size),'')                  
         ,  ISNULL(P.CaseCnt,0)    
         ,  ISNULL(P.InnerPack,0)       
         ,  ISNULL(RTRIM(P.PackUOM3),'')             
         ,  ISNULL(RTRIM(LA.Lottable02),'')           
 			,  CASE WHEN ISNULL(ST.Storerkey,'')='' THEN OH.C_Company ELSE ST.Company END --NJOW01    
 		   ,  ISNULL(S1.SUSR2,'')                                       --CS01 		                                                                               --       
   ORDER BY ISNULL(RTRIM(OH.Orderkey),'')   
         ,  ISNULL(RTRIM(PH.PickHeaderKey),'')  
         ,  ISNULL(RTRIM(PD.Loc),'')                 
         ,  ISNULL(RTRIM(S.Style),'')               
         ,  ISNULL(RTRIM(S.Color),'')               
         ,  ISNULL(RTRIM(S.Size),'')    
           

   QUIT:  
  
   IF CURSOR_STATUS('LOCAL' , 'CURSOR_SO') in (0 , 1)  
   BEGIN  
      CLOSE CURSOR_SO  
      DEALLOCATE CURSOR_SO  
   END  
  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      execute nsp_logerror @n_err, @c_errmsg, 'isp_PiecePickList_ord'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTranCnt  
    BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END /* main procedure */  


GO