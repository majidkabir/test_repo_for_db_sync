SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReplToFPA_Wave_PickSlip1_1                     */
/* Creation Date: 08-FEB-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#269535- Replensihment Report for IDSHK LOR principle    */
/*          - Replenish To Forward Pick Area (FPA)                      */
/*          - Printed together with Move Ticket & Pickslip in a         */
/*            composite report                                          */
/*                                                                      */
/* Called By: RCM - Popup Pickslip WavePlan                             */
/*          : Datawindow - r_dw_replenishment_fpa_wave_pickslip_1_1     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/*15-JAN-2019   WLCHOOI   WMS-7670 - Add SkuInfo.ExtendedField02        */ 
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_ReplToFPA_Wave_PickSlip1_1] (
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
         , @c_firsttime       NVARCHAR(1)
         , @c_PrintedFlag     NVARCHAR(1)
 
   DECLARE @c_PickHeaderkey   NVARCHAR(10) 
         , @c_Storerkey       NVARCHAR(15) 
         , @c_ST_Company      NVARCHAR(45)
         , @c_Orderkey        NVARCHAR(10)
         , @c_OrderType       NVARCHAR(10)
         , @c_Route           NVARCHAR(10)
         , @c_ExternOrderkey  NVARCHAR(50)   --tlting_ext
         , @c_ExternPOKey     NVARCHAR(20)
         , @c_BuyerPO         NVARCHAR(20)
         , @c_InvoiceNo       NVARCHAR(20)
         , @dt_DeliveryDate   DATETIME
         , @c_Consigneekey    NVARCHAR(15)
         , @c_C_Company       NVARCHAR(45)                            
         , @c_C_Address1      NVARCHAR(45)
         , @c_C_Address2      NVARCHAR(45)
         , @c_C_Address3      NVARCHAR(45)
         , @c_C_Address4      NVARCHAR(45)
         , @c_BillToKey       NVARCHAR(15)
         , @c_B_Company       NVARCHAR(45)                         
         , @c_B_Address1      NVARCHAR(45)
         , @c_B_Address2      NVARCHAR(45)
         , @c_B_Address3      NVARCHAR(45)
         , @c_B_Address4      NVARCHAR(45)
         , @c_Notes           NVARCHAR(255)
         , @c_Notes2          NVARCHAR(255)
         , @n_Capacity        FLOAT   
         , @n_GrossWeight     FLOAT
         , @n_noOfTotes       INT

   DECLARE @c_Sku             NVARCHAR(20)
         , @c_SkuDescr        NVARCHAR(60)
         , @c_Altsku          NVARCHAR(20)
         , @c_Busr10          NVARCHAR(30)
         , @c_HazardousFlag   NVARCHAR(30)
         , @c_Loc             NVARCHAR(10)
         , @c_ID              NVARCHAR(20)    
         , @c_DropID          NVARCHAR(20) 
         , @n_CaseCnt         INT      
         , @n_Cartons         INT
         , @n_Pieces          INT
         , @c_PADescr         NVARCHAR(60)
         , @c_Lottable01      NVARCHAR(18)
         , @c_Lottable02      NVARCHAR(18)
         , @c_Lottable03      NVARCHAR(18)
         , @dt_Lottable04     DATETIME
		 , @c_ExtendedField02 NVARCHAR(60)    --(WL01)
		 , @c_ShowExtField02  NVARCHAR(1)     --(WL01)

   SET @n_StartTCnt  =  @@TRANCOUNT
   SET @n_Continue   =  1

   SET @c_PickHeaderkey = ''
   SET @c_Storerkey     = ''
   SET @c_ST_Company    = ''
   SET @c_Orderkey      = ''
   SET @c_OrderType     = ''
   SET @c_Route         = ''
   SET @c_ExternOrderkey= ''
   SET @c_ExternPOKey   = ''
   SET @c_BuyerPO       = ''
   SET @c_InvoiceNo     = ''

   SET @c_Consigneekey  = ''
   SET @c_C_Company     = ''                     
   SET @c_C_Address1    = ''
   SET @c_C_Address2    = ''
   SET @c_C_Address3    = ''
   SET @c_C_Address4    = ''
   SET @c_BillToKey     = ''
   SET @c_B_Company     = ''                  
   SET @c_B_Address1    = ''
   SET @c_B_Address2    = ''
   SET @c_B_Address3    = ''
   SET @c_B_Address4    = ''
   SET @c_Notes         = ''
   SET @c_Notes2        = ''
   SET @n_Capacity      = 0.00
   SET @n_GrossWeight   = 0.00
   SET @n_noOfTotes     = 0
                      
   SET @c_Sku           = ''
   SET @c_SkuDescr      = ''
   SET @c_Altsku        = ''
   SET @c_Busr10        = ''
   SET @c_HazardousFlag = ''
   SET @c_Loc           = ''
   SET @c_ID            = ''
   SET @c_DropID        = ''
   SET @n_CaseCnt       = 0
   SET @n_Cartons       = 0
   SET @n_Pieces        = 0
   SET @c_PADescr       = ''
   SET @c_Lottable01    = ''
   SET @c_Lottable02    = ''
   SET @c_Lottable03    = ''

   SET @c_ExtendedField02 = ''  --(WL01)
   SET @c_ShowExtField02 = ''  --(WL01)
  
   CREATE TABLE #TMP_PICK
         (  SeqNo          INT      IDENTITY(1,1)
         ,  Wavekey        NVARCHAR(10)
         ,  PrintedFlag    NVARCHAR(1)
         ,  PickHeaderkey  NVARCHAR(10)    
         ,  Storerkey      NVARCHAR(15) 
         ,  ST_Company     NVARCHAR(45)    
         ,  Orderkey       NVARCHAR(10)                            
         ,  OrderType      NVARCHAR(10)                         
         ,  Route          NVARCHAR(10)                            
         ,  ExternOrderkey NVARCHAR(50)       --tlting_ext
         ,  ExternPOKey    NVARCHAR(20)                            
         ,  BuyerPO        NVARCHAR(20)                            
         ,  InvoiceNo      NVARCHAR(20)                         
         ,  DeliveryDate   DATETIME    NULL                               
         ,  Consigneekey   NVARCHAR(15)                         
         ,  C_Company      NVARCHAR(45)                            
         ,  C_Address1     NVARCHAR(45)                            
         ,  C_Address2     NVARCHAR(45)                            
         ,  C_Address3     NVARCHAR(45)                         
         ,  C_Address4     NVARCHAR(45)                         
         ,  BillToKey      NVARCHAR(15)                         
         ,  B_Company      NVARCHAR(45) 
         ,  B_Address1     NVARCHAR(45)    
         ,  B_Address2     NVARCHAR(45)    
         ,  B_Address3     NVARCHAR(45) 
         ,  B_Address4     NVARCHAR(45)          
         ,  Notes          NVARCHAR(255)         
         ,  Notes2         NVARCHAR(255)      
         ,  Capacity       FLOAT                
         ,  GrossWeight    FLOAT 
         ,  NoOfTotes      INT              
         ,  Sku            NVARCHAR(20)         
         ,  SkuDescr       NVARCHAR(60)         
         ,  Altsku         NVARCHAR(20)         
         ,  Busr10         NVARCHAR(30)      
         ,  HazardousFlag  NVARCHAR(30)         
         ,  Loc            NVARCHAR(10)         
         ,  ID             NVARCHAR(20)               
         ,  DropID         NVARCHAR(20)
         ,  CaseCnt        INT         
         ,  Cartons        INT                 
         ,  Pieces         INT                        
         ,  PADescr        NVARCHAR(60)         
         ,  Lottable02     NVARCHAR(18)         
         ,  Lottable03     NVARCHAR(18)         
         ,  Lottable04     DATETIME    
		 ,  ExtendedField02 NVARCHAR(60) --(WL01)
		 ,  ShowExtField02 NVARCHAR(1)   --(WL01)
         )

   SET @c_Wavekey = SUBSTRING(@c_wavekey_type, 1, 10)
   SET @c_Type    = SUBSTRING(@c_wavekey_type, 11,2)

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE Wavekey = @c_wavekey AND Zone = '8')
   BEGIN
      SET @c_firsttime = 'N'
      SET @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SET @c_firsttime = 'Y'
      SET @c_PrintedFlag = 'N'
   END -- Record Not Exists

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
            
   -- Uses PickType as a Printed Flag
   -- Only update when PickHeader Exists
   IF @c_firsttime = 'N' 
   BEGIN
      BEGIN TRAN

      UPDATE PICKHEADER
      SET PickType = '1'
        , TrafficCop = NULL
      WHERE WaveKey = @c_wavekey
      AND Zone = '8'
      AND PickType = '0'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         IF @@TRANCOUNT >= 1
         BEGIN
            ROLLBACK TRAN
         END
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
         ELSE
         BEGIN
            SET @n_continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END
   END

   DECLARE ORD_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT 
          ISNULL(RTRIM(PICKHEADER.PickHeaderkey),'')
         ,ISNULL(RTRIM(ORDERS.Storerkey),'')
         ,ISNULL(RTRIM(STORER.Company),'')
         ,ORDERS.Orderkey 
         ,ISNULL(RTRIM(ORDERS.Type),'')
         ,ISNULL(RTRIM(ORDERS.Route),'')
         ,ISNULL(RTRIM(ORDERS.ExternOrderkey),'') 
         ,ISNULL(RTRIM(ORDERS.ExternPOkey),'')
         ,ISNULL(RTRIM(ORDERS.BuyerPO),'')
         ,ISNULL(RTRIM(ORDERS.InvoiceNo),'')
         ,ORDERS.DeliveryDate 
         ,ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
         ,ISNULL(RTRIM(ORDERS.C_Company),'')
         ,ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,ISNULL(RTRIM(ORDERS.C_Address2),'')
         ,ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,ISNULL(RTRIM(ORDERS.BillToKey),'')
         ,ISNULL(RTRIM(ORDERS.B_Company),'')
         ,ISNULL(RTRIM(ORDERS.B_Address1),'')
         ,ISNULL(RTRIM(ORDERS.B_Address2),'')
         ,ISNULL(RTRIM(ORDERS.B_Address3),'')
         ,ISNULL(RTRIM(ORDERS.B_Address4),'')
         ,ISNULL(RTRIM(CONVERT(NVARCHAR(4000),ORDERS.Notes)),'')
         ,ISNULL(RTRIM(CONVERT(NVARCHAR(4000),ORDERS.Notes2)),'') 
         ,ISNULL(ORDERS.Capacity,0.00)
         ,ISNULL(ORDERS.GrossWeight,0.00)
         ,CASE WHEN CBM.Long IS NULL OR RTO.Long IS NULL THEN 0.00 
               ELSE CEILING(ISNULL(ORDERS.Capacity,0.00) / CONVERT(FLOAT,ISNULL(CBM.Long,0.00)) * CONVERT(FLOAT, ISNULL(RTO.Long,0.00)))
               END
         ,ISNULL(CLK.Short,'N')     --(WL01)
   FROM WAVEDETAIL WITH (NOLOCK)
   JOIN ORDERS     WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN STORER     WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON (WAVEDETAIL.Wavekey = PICKHEADER.Wavekey)
                                      AND(WAVEDETAIL.Orderkey= PICKHEADER.Orderkey)
                                      AND(PICKHEADER.Zone = '8')
   LEFT JOIN CODELKUP CBM WITH (NOLOCK) ON (CBM.ListName = 'ToteCBM')
                                        AND(CBM.Storerkey= ORDERS.Storerkey)
   LEFT JOIN CODELKUP RTO WITH (NOLOCK) ON (RTO.ListName = 'Ratio')
                                        AND(RTO.Storerkey= ORDERS.Storerkey)
   LEFT JOIN CODELKUP CLK WITH (NOLOCK) ON (CLK.ListName = 'REPORTCFG')       --(WL01)
                                        AND(CLK.Storerkey= ORDERS.Storerkey)
										AND(CLK.Code = 'ShowExtField02')
										AND(CLK.Long = 'r_dw_replenishment_fpa_wave_pickslip_1')
   WHERE WAVEDETAIL.Wavekey = @c_wavekey
   AND   ORDERS.Userdefine08 = 'Y'
   AND   PICKDETAIL.Status < '5'
   AND ( PICKDETAIL.Pickmethod = '8' OR PICKDETAIL.Pickmethod = ' ' ) 
   AND   PICKDETAIL.Qty > 0
   ORDER BY ORDERS.Orderkey

   OPEN ORD_CUR
   
   FETCH NEXT FROM ORD_CUR INTO @c_PickHeaderkey 
                              , @c_Storerkey
                              , @c_ST_Company
                              , @c_Orderkey
                              , @c_OrderType
                              , @c_Route
                              , @c_ExternOrderkey
                              , @c_ExternPOKey
                              , @c_BuyerPO
                              , @c_InvoiceNo
                              , @dt_DeliveryDate
                              , @c_Consigneekey
                              , @c_C_Company                               
                              , @c_C_Address1
                              , @c_C_Address2
                              , @c_C_Address3  
                              , @c_C_Address4  
                              , @c_BillToKey
                              , @c_B_Company                               
                              , @c_B_Address1
                              , @c_B_Address2
                              , @c_B_Address3  
                              , @c_B_Address4 
                              , @c_Notes
                              , @c_Notes2
                              , @n_Capacity  
                              , @n_GrossWeight 
                              , @n_NoOfTotes
							  , @c_ShowExtField02     --(WL01)
                              
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN 

      IF @c_PickHeaderkey = ''
      BEGIN  
         EXECUTE nspg_GetKey
               'PICKSLIP' 
            ,  9
            ,  @c_PickHeaderkey  OUTPUT 
            ,  @b_success        OUTPUT 
            ,  @n_err            OUTPUT 
            ,  @c_errmsg         OUTPUT

         SET @c_pickheaderkey = 'P' + @c_pickheaderkey
      
         BEGIN TRAN

         INSERT INTO PICKHEADER (PickHeaderKey,    OrderKey,    WaveKey, PickType, Zone, TrafficCop)
         VALUES (@c_pickheaderkey, @c_OrderKey, @c_wavekey,     '0',      '8',  '')
      
         SET @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_Continue = 3
            GOTO QUIT
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0 
            BEGIN
               COMMIT TRAN
            END
         END
      END -- Exist in PickHeader
      
      DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PICKDETAIL.Sku 
            ,ISNULL(RTRIM(SKU.Descr),'')
            ,ISNULL(RTRIM(SKU.AltSku),'')
            ,ISNULL(RTRIM(SKU.Busr10),'')
            ,ISNULL(RTRIM(SKU.HazardousFlag),'')
            ,CASE WHEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') <> '' THEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') ELSE PICKDETAIL.Loc END 
            ,ISNULL(RTRIM(PICKDETAIL.ID),'')
            ,ISNULL(RTRIM(PICKDETAIL.DropID), '')
            ,ISNULL(CONVERT(INT, PACK.CaseCnt),0)
            ,Carton = CASE WHEN ISNULL(CONVERT(INT, PACK.CaseCnt),0) > 0 
                           THEN SUM(PICKDETAIL.Qty) / ISNULL(CONVERT(INT, PACK.CaseCnt),0)
                           ELSE 0
                           END
            ,Pieces = CASE WHEN ISNULL(CONVERT(INT, PACK.CaseCnt),0) > 0 
                           THEN SUM(PICKDETAIL.Qty) % ISNULL(CONVERT(INT, PACK.CaseCnt),0)  
                           ELSE SUM(PICKDETAIL.Qty)
                           END
            ,CASE WHEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') <> '' THEN ISNULL(RTRIM(TZ.Descr),'') ELSE ISNULL(RTRIM(Z.Descr),'') END
            ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
            ,ISNULL(RTRIM(LOTATTRIBUTE.Lottable03),'')   
            ,ISNULL(LOTATTRIBUTE.Lottable04, CONVERT(DATETIME,'19000101'))  
			,ISNULL(SI.ExtendedField02,'')        --(WL01)       
      FROM PICKDETAIL          WITH (NOLOCK)
      JOIN SKU                 WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)
                                             AND(PICKDETAIL.Sku = SKU.Sku)
      JOIN PACK                WITH (NOLOCK) ON (Sku.Packkey = PACK.Packkey)
      JOIN LOTATTRIBUTE        WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)  
      JOIN LOC              L  WITH (NOLOCK) ON (PICKDETAIL.Loc = L.Loc)
      JOIN PUTAWAYZONE      Z  WITH (NOLOCK) ON (L.Putawayzone  = Z.Putawayzone)
	  LEFT JOIN SKUINFO          SI WITH (NOLOCK) ON (SI.Storerkey = SKU.Storerkey) AND (SI.SKU = SKU.SKU) --(WL01)
      LEFT JOIN LOC         TL WITH (NOLOCK) ON (PICKDETAIL.ToLoc = TL.Loc)  
      LEFT JOIN PUTAWAYZONE TZ WITH (NOLOCK) ON (TL.Putawayzone = TZ.Putawayzone)
                               
      WHERE PICKDETAIL.OrderKey = @c_Orderkey
      AND   PICKDETAIL.Status < '5'
      AND ( PICKDETAIL.Pickmethod = '8' OR PICKDETAIL.Pickmethod = ' ' )
      AND   PICKDETAIL.Qty > 0
      GROUP BY PICKDETAIL.Sku 
            ,  ISNULL(RTRIM(SKU.Descr),'')
            ,  ISNULL(RTRIM(SKU.AltSku),'')
            ,  ISNULL(RTRIM(SKU.Busr10),'')
            ,  ISNULL(RTRIM(SKU.HazardousFlag),'')
            ,  CASE WHEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') <> '' THEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') ELSE PICKDETAIL.Loc END 
            ,  CASE WHEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') <> '' THEN ISNULL(RTRIM(TL.LogicalLocation),'') ELSE ISNULL(RTRIM(L.LogicalLocation),'') END
            ,  ISNULL(RTRIM(PICKDETAIL.ID),'')
            ,  ISNULL(RTRIM(PICKDETAIL.DropID), '')
            ,  ISNULL(CONVERT(INT, PACK.CaseCnt),0) 
            ,  CASE WHEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') <> '' THEN ISNULL(RTRIM(TZ.Descr),'') ELSE ISNULL(RTRIM(Z.Descr),'') END
            ,  ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
            ,  ISNULL(RTRIM(LOTATTRIBUTE.Lottable03),'')   
            ,  ISNULL(LOTATTRIBUTE.Lottable04, CONVERT(DATETIME,'19000101'))   
			,  ISNULL(SI.ExtendedField02,'')    --(WL01)
      ORDER BY ISNULL(RTRIM(SKU.Busr10),'')
            ,  CASE WHEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') <> '' THEN ISNULL(RTRIM(TZ.Descr),'') ELSE ISNULL(RTRIM(Z.Descr),'') END
            ,  CASE WHEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') <> '' THEN ISNULL(RTRIM(TL.LogicalLocation),'') ELSE ISNULL(RTRIM(L.LogicalLocation),'') END
            ,  CASE WHEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') <> '' THEN ISNULL(RTRIM(PICKDETAIL.ToLoc), '') ELSE PICKDETAIL.Loc END 
            ,  ISNULL(RTRIM(PICKDETAIL.DropID), '')
            ,  ISNULL(RTRIM(PICKDETAIL.ID),'')
            ,  PICKDETAIL.Sku

      OPEN PICK_CUR

      FETCH NEXT FROM PICK_CUR INTO @c_sku
                                 ,  @c_SkuDescr
                                 ,  @c_AltSku
                                 ,  @c_Busr10
                                 ,  @c_HazardousFlag
                                 ,  @c_Loc
                                 ,  @c_ID
                                 ,  @c_DropID
                                 ,  @n_CaseCnt
                                 ,  @n_Cartons
                                 ,  @n_Pieces
                                 ,  @c_PADescr
                                 ,  @c_Lottable02
                                 ,  @c_Lottable03
                                 ,  @dt_Lottable04
								 ,  @c_ExtendedField02    --(WL01)

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN 
         INSERT INTO #TMP_PICK 
            (  Wavekey
            ,  PrintedFlag
            ,  PickHeaderkey 
            ,  Storerkey     
            ,  ST_Company    
            ,  Orderkey      
            ,  OrderType     
            ,  Route         
            ,  ExternOrderkey
            ,  ExternPOKey   
            ,  BuyerPO       
            ,  InvoiceNo     
            ,  DeliveryDate  
            ,  Consigneekey  
            ,  C_Company     
            ,  C_Address1    
            ,  C_Address2    
            ,  C_Address3    
            ,  C_Address4    
            ,  BillToKey     
            ,  B_Company     
            ,  B_Address1    
            ,  B_Address2    
            ,  B_Address3    
            ,  B_Address4    
            ,  Notes         
            ,  Notes2        
            ,  Capacity      
            ,  GrossWeight 
            ,  NoOfTotes       
            ,  Sku           
            ,  SkuDescr      
            ,  Altsku        
            ,  Busr10        
            ,  HazardousFlag 
            ,  Loc           
            ,  ID            
            ,  DropID   
            ,  CaseCnt     
            ,  Cartons       
            ,  Pieces        
            ,  PADescr       
            ,  Lottable02    
            ,  Lottable03    
            ,  Lottable04 
			,  ExtendedField02       --(WL01)
			,  ShowExtField02        --(WL01)
            )   
    VALUES  (  @c_Wavekey
            ,  @c_PrintedFlag
            ,  @c_PickHeaderkey 
            ,  @c_Storerkey     
            ,  @c_ST_Company    
            ,  @c_Orderkey      
            ,  @c_OrderType     
            ,  @c_Route         
            ,  @c_ExternOrderkey
            ,  @c_ExternPOKey   
            ,  @c_BuyerPO       
            ,  @c_InvoiceNo     
            ,  @dt_DeliveryDate  
            ,  @c_Consigneekey  
            ,  @c_C_Company     
            ,  @c_C_Address1    
            ,  @c_C_Address2    
            ,  @c_C_Address3    
            ,  @c_C_Address4    
            ,  @c_BillToKey     
            ,  @c_B_Company     
            ,  @c_B_Address1    
            ,  @c_B_Address2    
            ,  @c_B_Address3    
            ,  @c_B_Address4    
            ,  @c_Notes         
            ,  @c_Notes2        
            ,  @n_Capacity      
            ,  @n_GrossWeight    
            ,  @n_NoOfTotes       
            ,  @c_Sku           
            ,  @c_SkuDescr      
            ,  @c_Altsku        
            ,  @c_Busr10        
            ,  @c_HazardousFlag 
            ,  @c_Loc           
            ,  @c_ID            
            ,  @c_DropID   
            ,  @n_CaseCnt    
            ,  @n_Cartons       
            ,  @n_Pieces        
            ,  @c_PADescr      
            ,  @c_Lottable02    
            ,  @c_Lottable03    
            ,  @dt_Lottable04    
			,  @c_ExtendedField02       --(WL01)
			,  @c_ShowExtField02        --(WL01)
            )          
            

         FETCH NEXT FROM PICK_CUR INTO @c_sku
                                    ,  @c_SkuDescr
                                    ,  @c_AltSku
                                    ,  @c_Busr10
                                    ,  @c_HazardousFlag
                                    ,  @c_Loc
                                    ,  @c_ID
                                    ,  @c_DropID
                                    ,  @n_CaseCnt
                                    ,  @n_Cartons
                                    ,  @n_Pieces
                                    ,  @c_PADescr
                                    ,  @c_Lottable02
                                    ,  @c_Lottable03
                                    ,  @dt_Lottable04
									,  @c_ExtendedField02       --(WL01)
      END
      CLOSE PICK_CUR
      DEALLOCATE PICK_CUR

      FETCH NEXT FROM ORD_CUR INTO @c_PickHeaderkey 
                                 , @c_Storerkey
                                 , @c_ST_Company
                                 , @c_Orderkey
                                 , @c_OrderType
                                 , @c_Route
                                 , @c_ExternOrderkey
                                 , @c_ExternPOKey
                                 , @c_BuyerPO
                                 , @c_InvoiceNo
                                 , @dt_DeliveryDate
                                 , @c_Consigneekey
                                 , @c_C_Company                               
                                 , @c_C_Address1
                                 , @c_C_Address2
                                 , @c_C_Address3  
                                 , @c_C_Address4  
                                 , @c_BillToKey
                                 , @c_B_Company                               
                                 , @c_B_Address1
                                 , @c_B_Address2
                                 , @c_B_Address3  
                                 , @c_B_Address4 
                                 , @c_Notes
                                 , @c_Notes2
                                 , @n_Capacity  
                                 , @n_GrossWeight 
                                 , @n_NoOfTotes
								 , @c_ShowExtField02 --(WL01)
   END
   CLOSE ORD_CUR
   DEALLOCATE ORD_CUR

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
QUIT:
   SELECT Wavekey
         ,PrintedFlag
         ,PickHeaderkey 
         ,Storerkey     
         ,ST_Company    
         ,Orderkey      
         ,OrderType     
         ,Route         
         ,ExternOrderkey
         ,ExternPOKey   
         ,BuyerPO       
         ,InvoiceNo     
         ,DeliveryDate  
         ,Consigneekey  
         ,C_Company     
         ,C_Address1    
         ,C_Address2    
         ,C_Address3    
         ,C_Address4    
         ,BillToKey     
         ,B_Company     
         ,B_Address1    
         ,B_Address2    
         ,B_Address3    
         ,B_Address4    
         ,Notes         
         ,Notes2        
         ,Capacity      
         ,GrossWeight
         ,NoOfTotes        
         ,Sku           
         ,SkuDescr      
         ,Altsku        
         ,Busr10        
         ,HazardousFlag 
         ,Loc           
         ,ID            
         ,DropID 
         ,CaseCnt       
         ,Cartons       
         ,Pieces        
         ,PADescr       
         ,Lottable02    
         ,Lottable03    
         ,CASE WHEN CONVERT(NVARCHAR(8), Lottable04,112) = '19000101' THEN NULL ELSE Lottable04 END   
		 ,ExtendedField02      --(WL01)
		 ,ShowExtField02       --(WL01)
   FROM #TMP_PICK
   ORDER BY SeqNo

   DROP TABLE #TMP_PICK

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ReplToFPA_Wave_PickSlip1_1'  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         
         COMMIT TRAN  
      END  
      RETURN  
   END  
END

GO