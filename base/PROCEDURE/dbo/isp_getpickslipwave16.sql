SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Stored Procedure: isp_GetPickSlipWave16                              */    
/* Creation Date: 16-APR-2018                                           */    
/* Copyright: IDS                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:WMS-4489  [CN] UA WAVE PICKING LIST(Datawindow)              */     
/*                                                                      */    
/* Called By: RCM - Generate Pickslip                                   */    
/*          : Datawindow - r_dw_print_wave_pickslip_16                  */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Purposes                                       */    
/* 17-JUL-2018  CSCHONG  WMS-5533   - Changes sorting logic (CS01)      */  
/* 06-SEP-2018  GRICK    INC0369977 - CHANGE OPEN QTY (G01)             */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GetPickSlipWave16] (    
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
         , @c_Orderkey         NVARCHAR(10)    
         , @c_PickSlipNo      NVARCHAR(10)    
    
     
   DECLARE   
           @c_Storerkey       NVARCHAR(15)     
         , @c_ST_Company      NVARCHAR(45)    
         , @c_Address         NVARCHAR(250)    
         , @c_Adddate         NVARCHAR(10)    
         , @c_DeliveryDate    NVARCHAR(10)    
         , @c_Contact1        NVARCHAR(30)     
         , @c_Sku             NVARCHAR(20)    
         , @c_Altsku          NVARCHAR(20)    
         , @c_Loc             NVARCHAR(10)    
         , @n_casecnt         FLOAT  
         , @n_Qty             INT    
         , @n_Openqty         INT  
         , @n_QtyAlloc        INT  
    
    
   SET @n_StartTCnt  =  @@TRANCOUNT    
   SET @n_Continue   =  1    
    
   SET @c_PickSlipNo = ''    
   SET @c_Storerkey     = ''    
   SET @c_ST_Company    = ''    
   SET @c_Orderkey      = ''    
                          
   SET @c_Sku           = ''    
   SET @c_Altsku        = ''    
   SET @c_Address       = ''    
   SET @c_Loc           = ''    
   SET @n_casecnt       = 0  
   
    
    
   SET @n_Qty           = 0    
   SET @n_OpenQty       = 0  
   SET @n_Qtyalloc      = 0    
  
    
    
   WHILE @@TranCount > 0      
   BEGIN      
      COMMIT TRAN      
   END     
    
           
   CREATE TABLE #TMP_PSLP16    
         (  Wavekey        NVARCHAR(10)    
         ,  Orderkey       NVARCHAR(10)    
         ,  PickSlipNo     NVARCHAR(10)     
         )    
      
   CREATE TABLE #TMP_PICK16    
         (  SeqNo          INT      IDENTITY(1,1)    
         ,  Wavekey        NVARCHAR(10)    
         ,  c_contact1     NVARCHAR(45)    
         ,  PickSlipNo     NVARCHAR(10)        
         ,  Storerkey      NVARCHAR(15)     
         ,  ST_Company     NVARCHAR(45)        
         ,  Orderkey       NVARCHAR(10)                            
         ,  CAdd           NVARCHAR(250)                             
         ,  AddDate        NVARCHAR(30)                                                            
         ,  DeliveryDate   NVARCHAR(10)                                   
         ,  Sku            NVARCHAR(20)             
         ,  Altsku         NVARCHAR(20)                       
         ,  Loc            NVARCHAR(10)             
         ,  CASECNT        FLOAT                  
         ,  OpenQty        INT    
         ,  Qty            INT                            
         ,  Qtyalloc       INT     
         )    
    
   SET @c_Wavekey = SUBSTRING(@c_wavekey_type, 1, 10)    
   SET @c_Type    = SUBSTRING(@c_wavekey_type, 11,2)    
    
   INSERT INTO #TMP_PSLP16    
         (  Wavekey             
         ,  Orderkey             
         ,  PickSlipNo          
         )    
   SELECT DISTINCT     
          WD.Wavekey    
         ,OH.OrderKey    
         ,PickSlipNo = ISNULL(RTRIM(PH.PickHeaderkey),'')    
   FROM WAVEDETAIL      WD  WITH (NOLOCK)    
   JOIN ORDERS  OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)    
   LEFT JOIN PICKHEADER PH  WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)                                      
   WHERE WD.Wavekey = @c_Wavekey    
    
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order    
    
   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT     
          Orderkey    
        , PickSlipNo     
   FROM #TMP_PSLP16    
   ORDER BY PickSlipNo          
    
   OPEN CUR_LOAD    
       
   FETCH NEXT FROM CUR_LOAD INTO @c_Orderkey   
                              ,  @c_PickSlipNo    
                                 
    
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN    
                            
    
      SELECT DISTINCT     
          @c_Storerkey      = MAX(ISNULL(RTRIM(OH.Storerkey),''))    
         ,@c_ST_Company     = MAX(ISNULL(RTRIM(ST.Company),''))    
         ,@c_contact1       = MAX(ISNULL(OH.C_contact1,''))  
         ,@c_Address        = MAX(ISNULL(c_city,'') + ISNULL(c_address1,'') +ISNULL(c_address2,'') +ISNULL(c_address3,'') +ISNULL(c_address4,'') )  
         ,@c_AddDate        = MAX(CONVERT(NVARCHAR(10),OH.AddDate, 103))     
         ,@c_DeliveryDate   = MAX(CONVERT(NVARCHAR(10),OH.DeliveryDate, 103)) 
		 ,@n_Openqty		= OH.OpenQty																	--G01
      FROM ORDERS OH WITH (NOLOCK)      
      JOIN STORER ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)    
      WHERE OH.Orderkey = @c_orderkey    
      GROUP BY OH.Orderkey , OH.OpenQty   
    
      DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT Loc            = PD.Loc    
            ,Altsku          = (SKU.altsku)  
            ,Sku            =  (PD.Sku)        
            ,Qty            = SUM(PD.Qty)    
       --   ,Openqty        = SUM(OD.openqty)																G01
            ,Qtyalloc       = SUM(OD.QtyAllocated)  
            ,casecnt        = P.CaseCnt  
      FROM ORDERDETAIL OD  WITH (NOLOCK)     
      JOIN PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)    
                                         AND(OD.OrderLineNumber = PD.OrderLineNumber)    
      JOIN SKU         SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)    
                                         AND(PD.Sku = SKU.Sku)    
      JOIN LOC   LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)    
      JOIN PACK P WITH(NOLOCK) ON P.PackKey =sku.PACKKey       
      WHERE OD.Orderkey = @c_Orderkey    
      GROUP BY PD.Loc    
               ,PD.Sku  
               ,sku.ALTSKU   
               ,p.casecnt  
      ORDER BY PD.Loc,   
               PD.sku   
    
      OPEN CUR_PICK    
          
      FETCH NEXT FROM CUR_PICK INTO @c_Loc                
                                 ,  @c_altsku              
                                 ,  @c_Sku                    
                                 ,  @n_Qty        
                     --          ,  @n_Openqty																	G01
                                 ,  @n_QtyAlloc  
                                 ,  @n_casecnt  
    
      WHILE (@@FETCH_STATUS <> -1)    
      BEGIN    
    
         INSERT INTO #TMP_PICK16    
            (    
            Wavekey            
         ,  c_contact1       
         ,  PickSlipNo      
         ,  Storerkey        
         ,  ST_Company          
         ,  Orderkey                                  
         ,  CAdd                               
         ,  AddDate                                                                 
         ,  DeliveryDate                                   
         ,  Sku                    
         ,  Altsku                              
         ,  Loc                 
         ,  CASECNT                    
         ,  OpenQty            
         ,  Qty                                        
         ,  Qtyalloc               
            )     
      VALUES(     
               @c_Wavekey            
            ,  @c_contact1        
            ,  @c_PickSlipNo      
            ,  @c_Storerkey          
            ,  @c_ST_Company         
            ,  @c_Orderkey                             
            ,  @c_address                             
            ,  @c_adddate                    
            ,  @c_DeliveryDate                                 
            ,  @c_Sku                 
            ,  @c_altsku  
            ,  @c_Loc                 
            ,  @n_casecnt                           
            ,  @n_Qty                        
            ,  @n_openqty  
            ,  @n_QtyAlloc     
            )         
         FETCH NEXT FROM CUR_PICK INTO @c_Loc                
                                 ,  @c_altsku              
                                 ,  @c_Sku                    
                                 ,  @n_Qty        
                              -- ,  @n_Openqty  
                                 ,  @n_QtyAlloc  
                                 ,  @n_casecnt        
      END    
      CLOSE CUR_PICK    
      DEALLOCATE CUR_PICK    
    
      FETCH NEXT FROM CUR_LOAD INTO @c_Orderkey    
                                 ,  @c_PickSlipNo    
                                    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave16'      
   END    
    
   SELECT Wavekey            
         ,  c_contact1       
         ,  PickSlipNo      
         ,  Storerkey        
         ,  ST_Company          
         ,  Orderkey                                  
         ,  CAdd                               
         ,  #TMP_PICK16.AddDate as AddDate                                                                 
         ,  DeliveryDate                                   
         ,  Sku                    
         ,  Altsku                              
         ,  #TMP_PICK16.Loc As Loc                 
         ,  CASECNT                    
         ,  OpenQty            
         ,  Qty                                        
         ,  Qtyalloc       
         ,  CASE WHEN Casecnt = 0 THEN 0 ELSE FLOOR(openqty/casecnt)END AS Cntqty        
         ,  CASE WHEN Casecnt = 0 THEN qty/1 ELSE (openqty%cast(casecnt AS INT))END AS pcsqty     
   FROM #TMP_PICK16    
 JOIN LOC L WITH (NOLOCK) ON L.loc = #TMP_PICK16.loc  
   ORDER BY PickSlipNo    
         ,  Orderkey     
         --,  Loc    
   ,  L.LocationGroup  
   ,  L.LocLevel   
   ,  L.LogicalLocation   
   ,  L.Loc  
         ,  SKU    
         ,  Altsku    
    
    
   DROP TABLE #TMP_PICK16    
    
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
      BEGIN TRAN     
   END    
       
   RETURN    
END    

GO