SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetWavePickSlip_10                             */
/* Creation Date: 28-APR-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#309528 - ANF - Exceed Picking Slip                      */
/*                                                                      */
/* Called By: RCM - Generate Pickslip                                   */
/*          : Datawindow - r_dw_print_wave_pickslip_10                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 25-Sep-2014  TLTING    Bug fix                                       */
/************************************************************************/

CREATE PROC [dbo].[isp_GetWavePickSlip_10] (
@c_wavekey_type          NVARCHAR(13)
)
AS

BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT           
         , @b_Success         INT
         , @n_Err             INT
         , @c_Errmsg          NVARCHAR(255)
         
   DECLARE @c_Wavekey         NVARCHAR(10)
         , @c_Type            NVARCHAR(2)
         , @c_Loadkey         NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_PrintedFlag     NVARCHAR(1) 
 
   DECLARE @c_PickHeaderkey   NVARCHAR(10) 
         , @c_Storerkey       NVARCHAR(15) 
         , @c_ST_Company      NVARCHAR(45)
         , @c_Orderkey        NVARCHAR(10)
         , @c_OrderType       NVARCHAR(10)
         , @c_Stop            NVARCHAR(10)
         , @c_ExternOrderkey  NVARCHAR(30)

         , @c_BuyerPO         NVARCHAR(20)
         , @c_OrderGroup      NVARCHAR(20)
         , @c_Sectionkey      NVARCHAR(10)
         , @c_DeliveryDate    NVARCHAR(10)
         , @c_Consigneekey    NVARCHAR(15)
         , @c_C_Company       NVARCHAR(45)
                           

         , @n_TotalCBM        FLOAT   
         , @n_TotalGrossWgt   FLOAT
         , @n_noOfTotes       INT

         , @c_PAZone          NVARCHAR(10)
         , @c_PADescr         NVARCHAR(60) 
         , @c_LogicalLoc      NVARCHAR(18)
         , @c_Sku             NVARCHAR(20)
         , @c_SkuDescr        NVARCHAR(60)
         , @c_HazardousFlag   NVARCHAR(30)
         , @c_Loc             NVARCHAR(10)
         , @c_ID              NVARCHAR(18)    
         , @c_DropID          NVARCHAR(20) 
         , @n_Qty             INT
         , @c_UserDefine02    NVARCHAR(18)


   SET @n_StartTCnt  =  @@TRANCOUNT
   SET @n_Continue   =  1

   SET @c_PickHeaderkey = ''
   SET @c_Storerkey     = ''
   SET @c_ST_Company    = ''
   SET @c_Orderkey      = ''
   SET @c_OrderType     = ''
   SET @c_Stop          = ''
   SET @c_ExternOrderkey= ''

   SET @c_BuyerPO       = ''
   SET @c_Consigneekey  = ''
   SET @c_C_Company     = ''                     

   SET @n_TotalCBM      = 0.00
   SET @n_TotalGrossWgt = 0.00
   SET @n_noOfTotes     = 0
                      
   SET @c_Sku           = ''
   SET @c_SkuDescr      = ''
   SET @c_HazardousFlag = ''
   SET @c_Loc           = ''
   SET @c_ID            = ''
   SET @c_DropID        = ''


   SET @n_Qty           = 0
   SET @c_PADescr       = ''
   SET @c_UserDefine02  = ''


   WHILE @@TranCount > 0  
   BEGIN  
      COMMIT TRAN  
   END 

       
   CREATE TABLE #TMP_PSLP
         (  Wavekey        NVARCHAR(10)
         ,  Loadkey        NVARCHAR(10)
         ,  PickSlipNo     NVARCHAR(10)
         ,  PrintedFlag    NVARCHAR(1)
         )
  
   CREATE TABLE #TMP_PICK
         (  SeqNo          INT      IDENTITY(1,1)
         ,  Wavekey        NVARCHAR(10)
         ,  PrintedFlag    NVARCHAR(1)
         ,  PickHeaderkey  NVARCHAR(10)    
         ,  Storerkey      NVARCHAR(15) 
         ,  ST_Company     NVARCHAR(45)    
         ,  Loadkey        NVARCHAR(10)                            
         ,  OrderType      NVARCHAR(10)                         
         ,  [Stop]         NVARCHAR(10)                             
         ,  ExternOrderkey NVARCHAR(30)                            
         ,  BuyerPO        NVARCHAR(20)                            
         ,  OrderGroup     NVARCHAR(20)  
         ,  SectionKey     NVARCHAR(10)                            
         ,  DeliveryDate   NVARCHAR(10)                               
         ,  Consigneekey   NVARCHAR(15)                         
         ,  C_Company      NVARCHAR(45)                            
         ,  TotalCBM       FLOAT                
         ,  TotalGrossWgt  FLOAT 
         ,  NoOfTotes      INT 
         ,  PAZone         NVARCHAR(10)
         ,  PADescr        NVARCHAR(60) 
         ,  LogicalLoc     NVARCHAR(18)
      
         ,  Sku            NVARCHAR(20)         
         ,  SkuDescr       NVARCHAR(60)         
         ,  HazardousFlag  NVARCHAR(30)         
         ,  Loc            NVARCHAR(10)         
         ,  ID             NVARCHAR(18)               
         ,  DropID         NVARCHAR(20)
         ,  Qty            INT                        
         ,  UserDefine02   NVARCHAR(18) 
         )

   SET @c_Wavekey = SUBSTRING(@c_wavekey_type, 1, 10)
   SET @c_Type    = SUBSTRING(@c_wavekey_type, 11,2)

   INSERT INTO #TMP_PSLP
         (  Wavekey         
         ,  Loadkey         
         ,  PickSlipNo      
         ,  PrintedFlag
         )
   SELECT DISTINCT 
          WD.Wavekey
         ,LPD.LoadKey
         ,PickSlipNo = ISNULL(RTRIM(PH.PickHeaderkey),'')
         ,CASE WHEN PH.PickHeaderKey IS NULL THEN 'N' ELSE 'Y' END
   FROM WAVEDETAIL      WD  WITH (NOLOCK)
   JOIN LOADPLANDETAIL  LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)
   LEFT JOIN PICKHEADER PH  WITH (NOLOCK) ON (WD.WaveKey = PH.Wavekey)
                                          AND(LPD.Loadkey = PH.ExternOrderkey)  
                                          AND(LPD.Loadkey = PH.Loadkey)
                                          AND(PH.Zone = 'LP')   
   WHERE WD.Wavekey = @c_Wavekey

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order

   BEGIN TRAN

   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT 
          Loadkey
        , PickSlipNo
        , PrintedFlag
   FROM #TMP_PSLP
   ORDER BY PickSlipNo      

   OPEN CUR_LOAD
   
   FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey
                              ,  @c_PickSlipNo
                              ,  @c_PrintedFlag

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF RTRIM(@c_PickSlipNo) = '' OR @c_PickSlipNo IS NULL
      BEGIN
         EXECUTE nspg_GetKey     
                  'PICKSLIP'  
               ,  9  
               ,  @c_Pickslipno OUTPUT  
               ,  @b_Success    OUTPUT  
               ,  @n_err        OUTPUT  
               ,  @c_errmsg     OUTPUT        
                        
         SET @c_Pickslipno = 'P' + @c_Pickslipno        
                    
         INSERT INTO PICKHEADER    
                  (  PickHeaderKey  
                  ,  Wavekey  
                  ,  Orderkey  
                  ,  ExternOrderkey  
                  ,  Loadkey  
                  ,  PickType  
                  ,  Zone  
                  ,  TrafficCop  
                  )    
         VALUES    
                  (  @c_Pickslipno  
                  ,  @c_Wavekey  
                  ,  ''  
                  ,  @c_Loadkey  
                  ,  @c_Loadkey  
                  ,  '0'   
                  ,  'LP'  
                  ,  ''  
                  )        
           
         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetWavePickSlip_10)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
            GOTO QUIT   
         END    
       
         UPDATE PICKDETAIL WITH (ROWLOCK)    
         SET  PickSlipNo = @c_PickSlipNo   
             ,EditWho = SUSER_NAME()  
             ,EditDate= GETDATE()   
             ,TrafficCop = NULL   
         FROM ORDERS     OH WITH (NOLOCK)  
         JOIN PICKDETAIL PD ON (OH.Orderkey = PD.Orderkey)    
         WHERE  OH.Loadkey = @c_Loadkey  

         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (ispRLWAV02)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
            GOTO QUIT   
         END               
           
         IF NOT EXISTS (SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK)     
                        WHERE PickSlipNo = @c_PickSlipNo  
                        AND   Loadkey    = @c_Loadkey)  
         BEGIN   
            INSERT INTO REFKEYLOOKUP     
                     (  PickDetailkey    
                     ,  Orderkey    
                     ,  OrderLineNumber    
                     ,  Loadkey    
                     ,  PickSlipNo    
                     )     
            SELECT   PD.PickDetailKey    
                  ,  PD.Orderkey    
                  ,  PD.OrderLineNumber    
                  ,  @c_Loadkey    
                  ,  @c_PickSlipNo     
            FROM ORDERS     OH WITH (NOLOCK)  
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)    
            WHERE  OH.Loadkey = @c_Loadkey  

            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN    
               SET @n_continue = 3    
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
               SET @n_err = 81010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert REFKEYLOOKUP Failed (ispRLWAV02)' 
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
               GOTO QUIT     
            END  
         END 
      END

      SELECT DISTINCT 
          @c_Storerkey      = MAX(ISNULL(RTRIM(OH.Storerkey),''))
         ,@c_ST_Company     = MAX(ISNULL(RTRIM(ST.Company),''))
         ,@c_OrderType      = CASE WHEN COUNT (DISTINCT ISNULL(RTRIM(OH.[Type]),'')) > 1 THEN 'MIXED'
                              ELSE MAX(ISNULL(RTRIM(OH.[Type]),'')) END
         ,@c_Stop           = CASE WHEN COUNT (DISTINCT ISNULL(RTRIM(OH.[Stop]),'')) > 1 THEN 'MIXED'
                              ELSE MAX(ISNULL(RTRIM(OH.[Stop]),'')) END
         ,@c_ExternOrderkey = CASE WHEN COUNT (DISTINCT ISNULL(RTRIM(OH.ExternOrderkey),'')) > 1 THEN 'MIXED'
                              ELSE MAX(ISNULL(RTRIM(OH.ExternOrderkey),'')) END
         ,@c_BuyerPO        = CASE WHEN COUNT (DISTINCT ISNULL(RTRIM(OH.BuyerPO),'')) > 1 THEN 'MIXED'
                              ELSE MAX(ISNULL(RTRIM(OH.BuyerPO),'')) END
         ,@c_OrderGroup     = CASE WHEN COUNT (DISTINCT ISNULL(RTRIM(OH.OrderGroup),'')) > 1 THEN 'MIXED'
                              ELSE MAX(ISNULL(RTRIM(OH.OrderGroup),'')) END
         ,@c_SectionKey     = CASE WHEN COUNT (DISTINCT ISNULL(RTRIM(OH.SectionKey),'')) > 1 THEN 'MIXED'
                              ELSE MAX(ISNULL(RTRIM(OH.SectionKey),'')) END
         ,@c_DeliveryDate   = CASE WHEN COUNT (DISTINCT CONVERT(NVARCHAR(10),OH.DeliveryDate, 120)) > 1 THEN 'MIXED'
                              ELSE MAX(CONVERT(NVARCHAR(10),OH.DeliveryDate, 103)) END
        -- ,@c_ConsigneeKey   = (SELECT CASE WHEN COUNT(DISTINCT ISNULL(RTRIM(OD.UserDefine02),'')) > 1 THEN 'MIXED' 
        --                              ELSE MAX(ISNULL(RTRIM(OD.UserDefine02),'')) END
        --                       FROM ORDERDETAIL OD WITH (NOLOCK)
        --                       WHERE OD.Loadkey = OH.Loadkey)
        -- ,@c_C_Company      = MAX(ISNULL(RTRIM(OH.C_Company),''))
      FROM ORDERS OH WITH (NOLOCK)  
      JOIN STORER ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
      WHERE OH.Loadkey = @c_Loadkey
      GROUP BY OH.Loadkey

      DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PAZone         = LOC.Putawayzone
            ,PADescr        = ISNULL(RTRIM(PA.Descr),'')
            ,LogicalLoc     = ISNULL(RTRIM(LOC.LogicalLocation),'')
            ,Loc            = PD.Loc
            ,DropID         = CASE WHEN ISNULL(RTRIM(PD.DropID),'') = '' THEN 'BLANK' + PD.Pickdetailkey ELSE PD.DropID END
            ,Sku            = CASE WHEN UCC.UCCNo IS NULL OR COUNT(DISTINCT UCC.Sku) <= 1 THEN MAX(PD.Sku)    ELSE 'UCC' END
            ,SkuDescr       = CASE WHEN UCC.UCCNo IS NULL OR COUNT(DISTINCT UCC.Sku) <= 1 THEN MAX(SKU.Descr) ELSE '' END
            ,ID             = PD.ID
            ,UserDefine02   = ISNULL(RTRIM(OD.UserDefine02),'')
            ,HazardousFlag  = CASE WHEN RIGHT(SKU.ItemClass,2) IN ('63','64') THEN 'Y' ELSE '' END
            ,Qty            = SUM(PD.Qty)
      FROM ORDERDETAIL OD  WITH (NOLOCK) 
      JOIN PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                         AND(OD.OrderLineNumber = PD.OrderLineNumber)
      JOIN SKU         SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                         AND(PD.Sku = SKU.Sku)
      JOIN LOC         LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
      JOIN PUTAWAYZONE PA  WITH (NOLOCK) ON (LOC.Putawayzone = PA.Putawayzone)
      LEFT JOIN UCC    UCC WITH (NOLOCK) ON (PD.DropID = UCC.UCCNo) 
                                         AND(PD.SKU = UCC.SKU)  --(Chee)      
      WHERE OD.Loadkey = @c_Loadkey
      GROUP BY LOC.Putawayzone
             , ISNULL(RTRIM(PA.Descr),'')
             , ISNULL(RTRIM(LOC.LogicalLocation),'') 
             , PD.Loc
             , CASE WHEN ISNULL(RTRIM(PD.DropID),'') = '' THEN 'BLANK' + PD.Pickdetailkey ELSE PD.DropID END
             , PD.ID
             , ISNULL(RTRIM(OD.UserDefine02),'')
             , ISNULL(RTRIM(PD.DropID),'')
             , CASE WHEN RIGHT(SKU.ItemClass,2) IN ('63','64') THEN 'Y' ELSE '' END
             , UCC.UCCNo
      ORDER BY LOC.Putawayzone
            ,  ISNULL(RTRIM(PA.Descr),'')
            ,  ISNULL(RTRIM(LOC.LogicalLocation),'') 
            ,  PD.Loc
            ,  ISNULL(RTRIM(OD.UserDefine02),'')
            ,  ISNULL(RTRIM(PD.DropID),'')

      OPEN CUR_PICK
      
      FETCH NEXT FROM CUR_PICK INTO @c_PAZone
                                 ,  @c_PADescr
                                 ,  @c_LogicalLoc      
                                 ,  @c_Loc            
                                 ,  @c_DropID          
                                 ,  @c_Sku            
                                 ,  @c_SkuDescr        
                                 ,  @c_ID             
                                 ,  @c_UserDefine02    
                                 ,  @c_HazardousFlag   
                                 ,  @n_Qty    

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN

         SELECT @c_ConsigneeKey = ISNULL(CASE WHEN COUNT(DISTINCT ISNULL(RTRIM(OD.UserDefine02),'')) > 1 THEN 'MIXED' 
                                         ELSE MAX(ISNULL(RTRIM(OD.UserDefine02),'')) END,'')
              , @c_C_Company    = ISNULL(CASE WHEN COUNT(DISTINCT ISNULL(RTRIM(OD.UserDefine02),'')) > 1 THEN 'MIXED' 
                                         ELSE MAX(ISNULL(RTRIM(ST.Company),'')) END,'')
         FROM ORDERDETAIL OD  WITH (NOLOCK)
         JOIN STORER      ST  WITH (NOLOCK) ON (ST.Storerkey = OD.UserDefine02)
         JOIN PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                            AND(OD.OrderLineNumber = PD.OrderLineNumber)
         JOIN LOC         LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
         WHERE OD.Loadkey = @c_Loadkey
         AND   LOC.Putawayzone = @c_PAZone 

         SELECT @n_TotalCBM      = SUM(PD.Qty * ISNULL(SKU.StdCube,0.00))
            ,   @n_TotalGrossWgt = SUM(PD.Qty * ISNULL(SKU.StdGrossWgt,0.00))
            ,   @n_NoOfTotes     = COUNT(DISTINCT CASE WHEN ISNULL(RTRIM(PD.DropID),'') = '' THEN NULL ELSE PD.DropID END )
         FROM ORDERDETAIL OD  WITH (NOLOCK)
         JOIN PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                            AND(OD.OrderLineNumber = PD.OrderLineNumber)
         JOIN LOC         LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
         JOIN SKU         SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                            AND(PD.Sku = SKU.Sku)
         WHERE OD.Loadkey = @c_Loadkey
         AND   LOC.Putawayzone = @c_PAZone

         SET @c_DropID = CASE WHEN @c_DropID Like 'BLANK%' THEN '' ELSE @c_DropID END

         INSERT INTO #TMP_PICK
            (
               Wavekey        
            ,  PrintedFlag    
            ,  PickHeaderkey  
            ,  Storerkey      
            ,  ST_Company     
            ,  Loadkey                           
            ,  OrderType                       
            ,  [Stop]                              
            ,  ExternOrderkey                     
            ,  BuyerPO                            
            ,  OrderGroup     
            ,  SectionKey                         
            ,  DeliveryDate                          
            ,  Consigneekey                    
            ,  C_Company                          
            ,  TotalCBM        
            ,  TotalGrossWgt  
            ,  NoOfTotes      
            ,  PAZone         
            ,  PADescr        
            ,  LogicalLoc     
            ,  Sku             
            ,  SkuDescr        
            ,  HazardousFlag   
            ,  Loc             
            ,  ID                    
            ,  DropID         
            ,  Qty                   
            ,  UserDefine02   
            ) 
      VALUES( 
               @c_Wavekey        
            ,  @c_PrintedFlag    
            ,  @c_PickSlipNo  
            ,  @c_Storerkey      
            ,  @c_ST_Company     
            ,  @c_Loadkey                         
            ,  @c_OrderType                       
            ,  @c_Stop                              
            ,  @c_ExternOrderkey                     
            ,  @c_BuyerPO                            
            ,  @c_OrderGroup     
            ,  @c_SectionKey                         
            ,  @c_DeliveryDate                          
            ,  @c_Consigneekey                    
            ,  @c_C_Company                          
            ,  @n_TotalCBM        
            ,  @n_TotalGrossWgt  
            ,  @n_NoOfTotes      
            ,  @c_PAZone         
            ,  @c_PADescr        
            ,  @c_LogicalLoc     
            ,  @c_Sku             
            ,  @c_SkuDescr        
            ,  @c_HazardousFlag   
            ,  @c_Loc             
            ,  @c_ID                    
            ,  @c_DropID         
            ,  @n_Qty                   
            ,  @c_UserDefine02 
            )     
         FETCH NEXT FROM CUR_PICK INTO @c_PAZone
                                    ,  @c_PADescr
                                    ,  @c_LogicalLoc       
                                    ,  @c_Loc            
                                    ,  @c_DropID          
                                    ,  @c_Sku            
                                    ,  @c_SkuDescr        
                                    ,  @c_ID             
                                    ,  @c_UserDefine02    
                                    ,  @c_HazardousFlag   
                                    ,  @n_Qty    
      END
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK

      FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey
                                 ,  @c_PickSlipNo
                                 ,  @c_PrintedFlag 
   END
   CLOSE CUR_LOAD
   DEALLOCATE CUR_LOAD
   
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
QUIT:

   IF CURSOR_STATUS('LOCAL' , 'CUR_LOAD') in (0 , 1)
   BEGIN
      CLOSE CUR_LOAD
      DEALLOCATE CUR_LOAD
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_PICK') in (0 , 1)
   BEGIN
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK
   END

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN 
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END 
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetWavePickSlip_10'  
   END

   SELECT Wavekey
         ,PrintedFlag
         ,PickHeaderkey 
         ,Storerkey     
         ,ST_Company    
         ,Loadkey      
         ,OrderType     
         ,[Stop]         
         ,ExternOrderkey
         ,BuyerPO       
         ,OrderGroup     
         ,SectionKey  
         ,DeliveryDate
         ,Consigneekey  
         ,C_Company     
         ,TotalCBM      
         ,TotalGrossWgt
         ,NoOfTotes
         ,PAZone
         ,PADescr         
         ,Sku           
         ,SkuDescr      
         ,HazardousFlag 
         ,Loc           
         ,ID            
         ,DropID 
         ,Qty        
         ,UserDefine02   
   FROM #TMP_PICK
   ORDER BY PickHeaderkey
         ,  Loadkey
         ,  PADescr
         ,  LogicalLoc
         ,  Loc
         ,  UserDefine02
         ,  DropID


   DROP TABLE #TMP_PICK

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
   
   RETURN
END

GO