SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Proc : isp_PiecePickList_wave                                 */    
/* Creation Date: 06-Apr-2021                                           */    
/* Copyright: IDS                                                       */    
/* Written by:CSCHONG                                                   */    
/*                                                                      */    
/* Purpose: WMS-16730 - [CN] CONVERSE PiecePicking Slip By Load report  */    
/*        : Copy & Modified from isp_PiecePickList_ord                  */    
/*                                                                      */    
/* Input Parameters: Wavekey                                           */    
/*                                                                      */    
/* Output Parameters: Report                                            */    
/*                                                                      */    
/* Return Status: NONE                                                  */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: r_dw_piecepickslip_bywave                                 */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/* 19-JUL-2021  CSCHONG  1.1  WMS-16730 merge with LIT modify and       */  
/*                             tested scripts (CS01)                    */  
/* 17-AUG-2022  CSCHONG  1.2  Devops Scripts Combine                    */
/* 17-AUG-2022  CSCHONG  1.2  Performance Tunning (CS02)                */
/* 14-SEP-2022  CSCHONG  1.2  Performance Tunning (CS03)                */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_PiecePickList_wave] (    
               @c_Facility       NVARCHAR(5)    
            ,  @c_Wavekey        NVARCHAR(10) )    
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
         ,  @c_Storerkey     NVARCHAR(20)   
         ,  @c_STStorerkey   NVARCHAR(20)  
         ,  @c_OHCompany     NVARCHAR(45)  
         ,  @c_STCompany     NVARCHAR(45)  
         ,  @c_Billtokey     NVARCHAR(45)  
         ,  @c_consigneekey  NVARCHAR(45)  
         ,  @c_SUSR2         NVARCHAR(20)    
         ,  @c_OHState       NVARCHAR(45)  
         ,  @c_OHCity        NVARCHAR(45)  
         ,  @c_STState       NVARCHAR(45)  
         ,  @c_STCity        NVARCHAR(45)  
         ,  @c_SStyle        NVARCHAR(10)   
         ,  @c_SSize         NVARCHAR(10)   
         ,  @c_Scolor        NVARCHAR(10)   
         ,  @c_PLOC          NVARCHAR(10)   
         ,  @n_PQty          INT  
         ,  @n_PCASECNT      FLOAT  
         ,  @c_PUOM3         NVARCHAR(10)     
         ,  @n_PInnerPack    FLOAT  
         ,  @c_Lottable02    NVARCHAR(18)   
    
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
  
   CREATE TABLE #TMPWAVELP  
   (   Loadkey      NVARCHAR(20)   
      ,OHCompany    NVARCHAR(45) NULL  
      ,STCompany    NVARCHAR(45) NULL  
      ,STStorerkey  NVARCHAR(20) NULL  
      ,BillTokey    NVARCHAR(45) NULL   
      ,Consigneekey NVARCHAR(45) NULL  
      ,SUSR2        NVARCHAR(20) NULL  
      ,OHState      NVARCHAR(45) NULL   
      ,OHCity       NVARCHAR(45) NULL   
      ,STState      NVARCHAR(45) NULL  
      ,STCity       NVARCHAR(45) NULL   
      ,SStyle       NVARCHAR(10) NULL  
      ,SSize        NVARCHAR(10) NULL  
      ,Scolor       NVARCHAR(10) NULL  
      ,PLOC         NVARCHAR(10) NULL  
      ,PQty         INT  
      ,PCASECNT     FLOAT  
      ,PUOM3        NVARCHAR(10) NULL    
      ,PInnerPack   FLOAT  
      ,Lottable02   NVARCHAR(18) NULL  
  
)  


    --CS02 S
    CREATE TABLE #TMPWAVELPBULK
                  (loadkey          NVARCHAR(20),
                  TotalQtyInBulk    INT,
                  TLPAddate         DATETIME)     --CS03
    --CS02 E
     
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  
  
  --SELECT 'start', GETDATE()  

    --CS02 S

    INSERT INTO #TMPWAVELPBULK
         (
             loadkey,
             TotalQtyInBulk,TLPAddate
         )
         SELECT ISNULL(RTRIM(ORD.loadkey),'')    AS loadkey                        --CS03  
                            ,  ISNULL(SUM(PD.Qty),0) AS TotalQtyInBulk  
                            , ISNULL(LP.AddDate,'1900/01/01')                                           --CS03
                        --  FROM wavedetail WVDET WITH (NOLOCK)
                          FROM ORDERS ORD WITH (NOLOCK) --ON ORD.ORDERKEY = WVDET.ORDERKEY
                          JOIN LoadPlan LP WITH (NOLOCK)  ON LP.LoadKey = ORD.LoadKey   
                          JOIN PickDetail     PD  WITH (NOLOCK) ON PD.orderkey = ORD.Orderkey--ON (PD.PickSlipNo     = PH.pickheaderkey)  
                          JOIN LOC L WITH (NOLOCK) ON L.loc=PD.loc
                         WHERE ORD.Facility = @c_facility  
                           --AND WVDET.WaveKey = @c_Wavekey  
                           AND ORD.UserDefine09 = @c_Wavekey            --CS03
                          AND L.LocationType ='OTHER' AND L.LocationCategory='BULK'
                        GROUP BY ISNULL(RTRIM(ORD.loadkey),'') ,LP.AddDate  --CS03
    --CS02 E
  
   DECLARE CURSOR_SO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT          MAX(ISNULL(RTRIM(ORD.LoadKey),'')) ,MAX(ORD.storerkey)                        --CS03
                  ,MAX(ORD.C_Company),ISNULL(MAX(ST.Company),'')  
                  ,ISNULL(MAX(ST.StorerKey),''),MAX(ORD.BillToKey),MAX(ord.ConsigneeKey),MAX(S1.SUSR2)   
                  ,ISNULL(RTRIM(MAX(ORD.C_State)),'') , ISNULL(RTRIM(MAX(ORD.C_City)),'')  
                  ,ISNULL(RTRIM(MAX(ST.State)),''), ISNULL(RTRIM(MAX(ST.City)),'')  
                  ,s.Style,s.size,s.color,pd.loc,sum(DISTINCT pd.qty),P.CaseCnt,p.PackUOM3,p.InnerPack  
                  ,LA.Lottable02   
    --FROM wavedetail WVDET WITH (NOLOCK)                                      --CS02 S
    FROM ORDERS ORD WITH (NOLOCK) --ON ORD.ORDERKEY = WVDET.ORDERKEY  
    --JOIN LoadPlan LP WITH (NOLOCK)  ON LP.LoadKey = ORD.LoadKey             
    --JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = LP.Loadkey)      --CS03 E  
   -- JOIN PickDetail     PD  WITH (NOLOCK) ON (PD.Orderkey = LPD.Orderkey)    
       
    JOIN PickHeader     PH  WITH (NOLOCK) ON (PH.ExternOrderKey = ORD.LoadKey)     
  --                                        AND(PH.Orderkey       = OH.Orderkey)    
    JOIN PickDetail     PD  WITH (NOLOCK) ON (PD.PickSlipNo     = PH.pickheaderkey)   
    JOIN SKU            S   WITH (NOLOCK) ON (S.Storerkey       = PD.StorerKey)    
                                          AND(S.Sku             = PD.Sku)    
    JOIN SKUxLOC        SL  WITH (NOLOCK) ON (SL.Storerkey= PD.Storerkey)    
                                           AND(SL.Sku      = PD.Sku)    
                                           AND(SL.Loc      = PD.Loc)   
    JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PACKKey  
    JOIN LotAttribute   LA  WITH (NOLOCK) ON (LA.Lot            = PD.Lot)  
    LEFT JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = ISNULL(RTRIM(ORD.BillToKey),'') + ISNULL(RTRIM(ORD.ConsigneeKey),''))    
    LEFT JOIN Storer S1 WITH (NOLOCK) ON S1.StorerKey=ORD.ConsigneeKey        
    WHERE  ORD.Facility     =  @c_facility        --CS03
   -- AND WVDET.WaveKey = @c_wavekey              --CS03
       AND ORD.UserDefine09 = @c_Wavekey                --CS03  
    -- AND  SL.Locationtype = 'PICK'     --CS01 START   
    --AND  PD.Status       < '5'        
    AND  PD.Qty > 0        
    AND PD.uom <> '6'             ----- Luna 7.14  --CS01 END  
   GROUP BY s.Style,s.size,p.CaseCnt,pd.loc,s.Color,p.CaseCnt,p.PackUOM3,p.InnerPack,LA.Lottable02  --CS03
   ORDER BY MAX(ISNULL(RTRIM(ORD.LoadKey),''))          --CS03    
         --,  ISNULL(RTRIM(LPD.OrderKey),'')    
    
   OPEN CURSOR_SO    
    
   FETCH NEXT FROM CURSOR_SO INTO @c_LoadKey    
                                 ,@c_Storerkey  
                                 ,@c_OHCompany  
                                 ,@c_STCompany  
                                 ,@c_STStorerkey  
                                 ,@c_Billtokey  
                                 ,@c_consigneekey  
                                 ,@c_SUSR2  
                                 ,@c_OHState  
                                 ,@c_OHCity  
                                 ,@c_STState  
                                 ,@c_STCity    
                                 ,@c_SStyle         
                                 ,@c_SSize          
                                 ,@c_Scolor          
                                 ,@c_PLOC           
                                 ,@n_PQty            
                                 ,@n_PCASECNT        
                                 ,@c_PUOM3           
                                 ,@n_PInnerPack      
                                 ,@c_Lottable02      
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
  
    -- SELECT @c_LoadKey '@c_LoadKey'  
      IF NOT EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_LoadKey     
                                                           AND Zone = '5')     
      BEGIN    
  
    --    SELECT 'insert PickHeader'  
  
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
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Getting PickSlip #. (isp_PiecePickList_wave)'    
            GOTO QUIT    
         END    
         ELSE   
         BEGIN  
            COMMIT TRAN  
         END  
    
         SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey    
  
        --SELECT @c_PickHeaderKey '@c_PickHeaderKey'  
         BEGIN TRAN    
         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, OrderKey, Zone,StorerKey,LoadKey)    
         VALUES (@c_PickHeaderKey, @c_LoadKey, '', '5',@c_Storerkey,@c_LoadKey)    
              
         SET @n_err = @@ERROR    
       
         IF @n_err <> 0     
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 63502    
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (isp_PiecePickList_wave)'    
            GOTO QUIT    
         END    
         ELSE   
         BEGIN  
            COMMIT TRAN  
         END  
      END    
  
      INSERT INTO #TMPWAVELP  
      (  
          Loadkey,  
          OHCompany,  
          STCompany,  
          STStorerkey,  
          BillTokey,  
          Consigneekey,  
          SUSR2,  
          OHState,  
          OHCity,  
          STState,  
          STCity,  
          SStyle,         
          SSize,         
          Scolor,        
          PLOC,           
          PQty,           
          PCASECNT,       
          PUOM3,         
          PInnerPack,     
          Lottable02     
      )  
      VALUES  
      (   @c_LoadKey    
         ,@c_OHCompany  
         ,@c_STCompany  
         ,@c_STStorerkey  
         ,@c_Billtokey  
         ,@c_consigneekey  
         ,@c_SUSR2  
         ,@c_OHState  
         ,@c_OHCity  
         ,@c_STState  
         ,@c_STCity    
         ,@c_SStyle         
         ,@c_SSize          
         ,@c_Scolor          
         ,@c_PLOC           
         ,@n_PQty            
         ,@n_PCASECNT        
         ,@c_PUOM3           
         ,@n_PInnerPack      
         ,@c_Lottable02   
          )  
      FETCH NEXT FROM CURSOR_SO INTO @c_LoadKey    
                                    ,@c_Storerkey  
                                    ,@c_OHCompany  
                                    ,@c_STCompany  
                                    ,@c_STStorerkey  
                                    ,@c_Billtokey  
                                    ,@c_consigneekey  
                                    ,@c_SUSR2  
                                    ,@c_OHState  
                                    ,@c_OHCity  
                                    ,@c_STState  
                                    ,@c_STCity    
                                    ,@c_SStyle         
                                    ,@c_SSize          
                                    ,@c_Scolor          
                                    ,@c_PLOC           
                                    ,@n_PQty            
                                    ,@n_PCASECNT        
                                    ,@c_PUOM3           
                                    ,@n_PInnerPack      
                                    ,@c_Lottable02      
   END     
   CLOSE CURSOR_SO    
   DEALLOCATE CURSOR_SO    
  
   WHILE @@TRANCOUNT < @n_StartTranCnt  
      BEGIN TRAN  
 -- SELECT '123' , * FROM #TMPWAVELP  
  
   SELECT ISNULL(RTRIM(ORD.LoadKey),'')          AS Loadkey                --CS03
         ,ISNULL(RTRIM(PH.PickHeaderKey),'')    AS PickHeaderKey     
         --,CASE WHEN MAX(ST.Storerkey) IS NULL THEN ISNULL(RTRIM(MAX(OH.C_State)),'') + ISNULL(RTRIM(MAX(OH.C_City)),'')    
         --                                ELSE ISNULL(RTRIM(MAX(ST.State)),'') + ISNULL(RTRIM(MAX(ST.City)),'')    
         --                                END    AS City    
          ,CASE WHEN (TLP.STStorerkey) IS NULL THEN ISNULL(RTRIM((TLP.OHState)),'') + ISNULL(RTRIM((TLP.OHCity)),'')    
                                         ELSE ISNULL(RTRIM((TLP.STState)),'') + ISNULL(RTRIM((TLP.STCity)),'')    
                                         END    AS City    
         ,ISNULL(TPD.TLPAddate,'1900/01/01')       AS AddDate    
         , ORD.UserDefine09                        AS Wavekey        --CS03
         ,''                                    AS ExternOrderkey    
         --,ISNULL(RTRIM(MAX(OH.BillTokey)),'') + '-'     
         --+ISNULL(RTRIM(MAX(OH.ConsigneeKey)),'')     AS CustomerNo    
         ,ISNULL(RTRIM(MAX(TLP.BillTokey)),'') + '-'     
         +ISNULL(RTRIM(MAX(TLP.ConsigneeKey)),'')     AS CustomerNo  
         ,ISNULL(TOD.TotalQtyOrdered,0)         AS TotalQtyOrdered    
         ,ISNULL(TPD.TotalQtyInBulk,0)          AS TotalQtyInBulk    
         ,ISNULL(RTRIM(TLP.PLOC),'')              AS Loc    
         ,ISNULL(RTRIM(TLP.SStyle),'')             AS Style    
         ,ISNULL(RTRIM(TLP.SColor),'')             AS Color    
         ,ISNULL(RTRIM(TLP.SSize),'')              AS Size    
         ,ISNULL((TLP.PQty),0)                 AS Qty     
         ,'Pack (' + ISNULL(RTRIM(TLP.PUOM3),'')     
         + 'x' + CONVERT(NVARCHAR(10), ISNULL(TLP.PCaseCnt,0)) + ')' AS PackDesc    
         ,ISNULL(TLP.PCaseCnt,0)                   AS CaseCnt    
         ,ISNULL(TLP.PInnerPack,0)                 AS InnerPack    
         ,ISNULL(RTRIM(TLP.PUOM3),'')              AS PackUOM3    
         ,ISNULL(RTRIM(TLP.Lottable02),'')         AS Lotable02   
         ,CASE WHEN ISNULL(TLP.STStorerkey,'')='' THEN (TLP.OHCompany) ELSE (TLP.STCompany) END AS Company     
         ,ISNULL(TLP.SUSR2,'')   AS SSUSR2                                                                                                                                                --         
   -- FROM wavedetail WVDET WITH (NOLOCK)  
    FROM ORDERS ORD WITH (NOLOCK) --ON ORD.ORDERKEY = WVDET.ORDERKEY  
   -- JOIN LoadPlan LP WITH (NOLOCK)  ON LP.LoadKey = ORD.LoadKey  
   -- JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey       = LP.LoadKey)     
    --JOIN Orders         OH  WITH (NOLOCK) ON (OH.Orderkey       = LPD.Orderkey)    
    JOIN PickHeader     PH  WITH (NOLOCK) ON (PH.ExternOrderKey = ORD.LoadKey)     
  ----                                        AND(PH.Orderkey       = OH.Orderkey)    
    JOIN PickDetail     PD  WITH (NOLOCK) ON (PD.PickSlipNo     = PH.pickheaderkey)     
    --JOIN (SELECT ISNULL(RTRIM(OH.loadkey),'')    AS loadkey             --CS02 S
    --           , ISNULL(SUM(OD.OpenQty),0) AS TotalQtyOrdered     
    --        FROM Orders OH WITH (NOLOCK)  
    --       JOIN ORDERDETAIL OD WITH (NOLOCK)  ON OH.OrderKey=OD.OrderKey    
    --      GROUP BY ISNULL(RTRIM(OH.loadkey),'') ) TOD       
    --                                      ON (TOD.loadkey = LP.loadkey)    
CROSS APPLY (SELECT DISTINCT ISNULL(RTRIM(OH.loadkey),'')    AS loadkey  
               , ISNULL(SUM(OD.OpenQty),0) AS TotalQtyOrdered   
            FROM Orders OH WITH (NOLOCK)
           JOIN ORDERDETAIL OD WITH (NOLOCK)  ON OH.OrderKey=OD.OrderKey AND OH.OrderKey=ORD.OrderKey
          GROUP BY ISNULL(RTRIM(OH.loadkey),'') ) TOD       
    --LEFT JOIN (SELECT ISNULL(RTRIM(LP.loadkey),'')    AS loadkey    
    --               ,  ISNULL(SUM(PD.Qty),0) AS TotalQtyInBulk    
    --             FROM wavedetail WVDET WITH (NOLOCK)  
    --             JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = WVDET.ORDERKEY  
    --             JOIN LoadPlan LP WITH (NOLOCK)  ON LP.LoadKey = ORD.LoadKey  
    --             JOIN PickDetail     PD  WITH (NOLOCK) ON PD.orderkey = ORD.Orderkey--ON (PD.PickSlipNo     = PH.pickheaderkey)    
    --             JOIN LOC L WITH (NOLOCK) ON L.loc=PD.loc  
    --            WHERE LP.Facility = @c_facility    
    --              AND WVDET.WaveKey = @c_Wavekey    
    --             AND L.LocationType ='OTHER' AND L.LocationCategory='BULK'  
    --           GROUP BY ISNULL(RTRIM(LP.loadkey),'')) TPD    
     LEFT JOIN #TMPWAVELPBULK TPD      ON (TPD.loadkey = ORD.Loadkey)    --CS02 E    --CS03
     LEFT JOIN #TMPWAVELP TLP ON TLP.Loadkey=ORD.LoadKey                             --CS03  
     WHERE ORD.Facility = @c_facility                                                --CS03
     AND ORD.UserDefine09 = @c_wavekey                                               --CS03
     AND PH.Zone     = '5'    
     --AND SL.LocationType = 'PICK'   ----- Luna 7.14     --CS01 START   
     --AND PD.STATUS  < '5'        
     AND PD.UOM <> '6'  ----- Luna 7.14                   --CS01 END  
     GROUP BY ISNULL(RTRIM(ORD.LoadKey),'')               --CS03
         ,  ISNULL(RTRIM(PH.PickHeaderKey),'')    
         ,   ORD.UserDefine09                                                         --CS03            
         ,CASE WHEN (TLP.STStorerkey) IS NULL THEN ISNULL(RTRIM((TLP.OHState)),'') + ISNULL(RTRIM((TLP.OHCity)),'')    
                                         ELSE ISNULL(RTRIM((TLP.STState)),'') + ISNULL(RTRIM((TLP.STCity)),'')    
                                         END            
         ,  ISNULL(TPD.TLPAddate,'1900/01/01')                                 --CS03 
         --,  ISNULL(RTRIM(OH.ExternOrderkey),'')      
         ,  ISNULL(RTRIM(TLP.BillTokey),'') + '-' + ISNULL(RTRIM(TLP.ConsigneeKey),'')          
         ,  ISNULL(TOD.TotalQtyOrdered,0)     
         ,  ISNULL(TPD.TotalQtyInBulk,0)               
         ,  ISNULL(RTRIM(TLP.PLOC),'')                   
         ,  ISNULL(RTRIM(TLP.SStyle),'')                  
         ,  ISNULL(RTRIM(TLP.SColor),'')                 
         ,  ISNULL(RTRIM(TLP.SSize),'')                    
         ,  ISNULL(TLP.PCaseCnt,0)      
         ,  ISNULL(TLP.PInnerPack,0)         
         ,  ISNULL(RTRIM(TLP.PUOM3),'')               
         ,  ISNULL(RTRIM(TLP.Lottable02),'')             
         --,  CASE WHEN ISNULL(ST.Storerkey,'')='' THEN OH.C_Company ELSE ST.Company END    
         ,  CASE WHEN ISNULL(TLP.STStorerkey,'')='' THEN (TLP.OHCompany) ELSE (TLP.STCompany) END   
         ,  ISNULL(TLP.SUSR2,'')  ,ISNULL((TLP.PQty),0)                                                                                                                     --         
   ORDER BY ISNULL(RTRIM(ORD.Loadkey),'')     
         ,  ISNULL(RTRIM(PH.PickHeaderKey),'')    
         ,  ISNULL(RTRIM(TLP.PLoc),'')                   
         ,  ISNULL(RTRIM(TLP.SStyle),'')                 
         ,  ISNULL(RTRIM(TLP.SColor),'')                 
         ,  ISNULL(RTRIM(TLP.SSize),'')      
             
  
   QUIT:    
    
   IF CURSOR_STATUS('LOCAL' , 'CURSOR_SO') in (0 , 1)    
   BEGIN    
      CLOSE CURSOR_SO    
      DEALLOCATE CURSOR_SO    
   END    
    
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      execute nsp_logerror @n_err, @c_errmsg, 'isp_PiecePickList_wave'    
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