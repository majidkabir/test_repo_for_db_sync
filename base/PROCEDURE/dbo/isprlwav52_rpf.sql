SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: ispRLWAV52_RPF                                          */  
/* Creation Date: 2022-05-12                                            */
/* Copyright: LF Logistics                                              */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose:  Duplicate from ispRLWAV20                                  */  
/*        :  WMS-19633 - TH-Nike-Wave Release                           */  
/*                                                                      */  
/* Called By: ReleaseWave_SP                                            */  
/*          :                                                           */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2022-05-12  Wan      1.0   Created.                                  */
/* 2022-05-12  Wan      1.0   DevOps Combine Script.                    */
/* 2022-07-27  Wan01    1.1   Fixed. Not to get Not tally UCC for replen*/
/* 2022-08-04  Wan02    1.2   Fixed Not get Wave.DispatchPiecePickMethod*/
/*                            to construct SourceType                   */
/* 2022-09-02  Wan03    1.3   WMS-20686 - TH-NIKE - customize Wave      */
/*                            Release V2022                             */
/************************************************************************/  
CREATE PROC [dbo].[ispRLWAV52_RPF]  
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
,  @b_debug       INT            = 0     
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt          INT   =  @@TRANCOUNT
         , @n_Continue           INT   =  1 
  
         , @c_DispatchPiecePickMethod NVARCHAR(10) =  ''  
  
         , @c_Loadkey            NVARCHAR(10)   = ''  
         , @c_Orderkey           NVARCHAR(10)   = ''
         , @c_Facility           NVARCHAR(5)    = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Sku                NVARCHAR(20)   = ''
         , @c_UOM                NVARCHAR(10)   = ''
         , @c_Lot                NVARCHAR(10)   = ''
         , @c_fromLoc            NVARCHAR(10)   = ''
         , @c_ID                 NVARCHAR(18)   = ''
         , @n_UCCQty             INT            = 0
         , @n_Qty                INT            = 0
         , @c_PickMethod         NVARCHAR(2)    = ''
         , @c_FromLocType        NVARCHAR(10)   = ''
         , @c_ToLocType          NVARCHAR(10)   = ''
         , @c_FromPAZone         NVARCHAR(10)   = ''
                                      
         , @c_TaskDetailKey      NVARCHAR(10)   = ''
         , @c_TaskType           NVARCHAR(10)   = ''
         , @c_LogicalFromLoc     NVARCHAR(10)   = ''
         , @c_LogicalToLoc       NVARCHAR(10)   = ''
         , @c_ToLoc              NVARCHAR(10)   = ''  
         , @c_SourceType         NVARCHAR(30)   = ''
         , @c_DropID             NVARCHAR(20)   = ''
                                           
         , @c_PickDetailKey      NVARCHAR(10)   = ''
         , @c_PickSlipNo         NVARCHAR(10)   = ''
         , @c_Consigneekey       NVARCHAR(15)   = ''
         , @c_Route              NVARCHAR(10)   = ''
  
         , @n_RowRef             INT            = 0
         , @c_LocationHandling   NVARCHAR(10)   = ''
         , @c_LocationType       NVARCHAR(10)   = ''
         , @c_LocationCategory   NVARCHAR(10)   = ''
                                               
         , @n_UCCWODPLoc         INT            = ''   
         , @c_DPPPKZone          NVARCHAR(10)   = ''             
         , @c_SkuGroup           NVARCHAR(10)   = '' 
         , @c_UOM_Prev           NVARCHAR(10)   = ''             
                                               
         , @n_NoOfUCC_Replen     INT            = ''             
         , @n_NoOfUCCInDP        INT            = ''             
            
         , @c_Lottable01         NVARCHAR(18)   = ''             
         , @c_LocationHandlings  NVARCHAR(10)   = ''             
  
         , @c_PreCTNLevel        CHAR(1)        = ''             
         , @c_PackOrderkey       NVARCHAR(10)   = ''             
         , @c_Zone               NVARCHAR(10)   = ''             
                                               
         , @c_ExternOrderkey     NVARCHAR(50)   = ''             
                                               
         , @c_MinPalletCarton    NVARCHAR(30)   = ''             
         , @n_TotatCartonInID    INT            = ''             
         , @n_MinPalletCarton    INT            = ''             
         , @n_NoOfUCCSku         INT            = ''             
         , @n_UCCWOBULKDPLoc     INT            = 0
              
         , @c_Wavekey_PD         NVARCHAR(10)   = ''
                                                
         , @c_logicalloc         NVARCHAR(10)   = ''
         , @c_logicallocStart    NVARCHAR(10)   = ''
                                                
         , @n_LocQty             INT            = 0 
         , @b_UpdMultiWave       BIT            = 0 
         , @b_DirectGenPickSlip  INT            = 0   
         , @c_TransitLoc         NVARCHAR(10)   = ''
         , @c_FinalLoc           NVARCHAR(10)   = ''
         , @c_FinalID            NVARCHAR(18)   = ''
         
         , @c_ReleaseWave_Authority    NVARCHAR(30)   = ''           --Wan03
         , @c_ReleaseWave_Opt5         NVARCHAR(1000) = ''           --Wan03
         , @c_SingleSkuPerDPLoc        CHAR(1)        = 'N'          --Wan03
         , @c_SQL                      NVARCHAR(4000) = ''           --Wan03
         , @c_SQLParms                 NVARCHAR(1000) = ''           --Wan03
                                                                    
         , @CUR_UPDPM            CURSOR   
              
   SET @b_Success  = 1
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
   SET @c_Facility = ''  
   SELECT TOP 1 @c_Facility = OH.Facility  
               ,@c_Storerkey= OH.Storerkey           
   FROM WAVEDETAIL WD WITH (NOLOCK)  
   JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey  
   WHERE WD.Wavekey= @c_Wavekey 
   
   --Wan03 - START
   SELECT @c_ReleaseWave_Authority = fgr.Authority
         ,@c_ReleaseWave_Opt5 = fgr.Option5
   FROM dbo.fnc_GetRight2( @c_Facility, @c_Storerkey, '', 'ReleaseWave_SP') AS fgr 
   
   SET @c_SingleSkuPerDPLoc = 'N' 
   SELECT @c_SingleSkuPerDPLoc = dbo.fnc_GetParamValueFromString('@c_SingleSkuPerDPLoc', @c_ReleaseWave_Opt5, @c_SingleSkuPerDPLoc) 
   --Wan03 - END
    
   DECLARE @t_UPDPICK TABLE  
   (  RowRef            INT   IDENTITY(1,1) PRIMARY KEY  
   ,  PickDetailKey     NVARCHAR(10)   NOT NULL DEFAULT ('')  
   ,  Loadkey           NVARCHAR(10)   NOT NULL DEFAULT ('')  
   ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT ('')  
   ,  Consigneekey      NVARCHAR(15)   NOT NULL DEFAULT ('')  
   ,  [Route]           NVARCHAR(10)   NOT NULL DEFAULT ('')  
   ,  ExternOrderkey    NVARCHAR(50)   NOT NULL DEFAULT ('')  
   ,  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT ('')    
   ,  Qty               INT            NOT NULL DEFAULT(0)                             
   )  
  
   DECLARE @t_DPRange TABLE  
   (  PickZone          NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY  
   ,  LogicalLocStart   NVARCHAR(10)   NOT NULL DEFAULT('')  
   )  
  
   IF OBJECT_ID('tempdb..#TMP_LOC_DP','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_LOC_DP;  
   END  
  
   CREATE TABLE #TMP_LOC_DP  
   (  
      Facility          NVARCHAR(5)    NOT NULL DEFAULT('')     
   ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT('') Primary Key  
   ,  LocationType      NVARCHAR(10)   NOT NULL DEFAULT('')   
   ,  LocationHandling  NVARCHAR(10)   NOT NULL DEFAULT('')        
   ,  LocationCategory  NVARCHAR(10)   NOT NULL DEFAULT('')   
   ,  LogicalLocation   NVARCHAR(10)   NOT NULL DEFAULT('')               
   ,  PickZone          NVARCHAR(10)   NOT NULL DEFAULT('')  
   ,  MaxPallet         INT            NOT NULL DEFAULT(0)    
   )       
     
   IF OBJECT_ID('tempdb..#TMP_LOC_DPP','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_LOC_DPP;  
   END  
  
   CREATE TABLE #TMP_LOC_DPP  
   (  
      Facility          NVARCHAR(5)    NOT NULL DEFAULT('')     
   ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT('') Primary Key  
   ,  LocationType      NVARCHAR(10)   NOT NULL DEFAULT('')   
   ,  LocationHandling  NVARCHAR(10)   NOT NULL DEFAULT('')        
   ,  LocationCategory  NVARCHAR(10)   NOT NULL DEFAULT('')   
   ,  LogicalLocation   NVARCHAR(10)   NOT NULL DEFAULT('')               
   ,  PickZone          NVARCHAR(10)   NOT NULL DEFAULT('')  
   ,  MaxPallet         INT            NOT NULL DEFAULT(0)    
   )                 
  
   CREATE TABLE #TMP_PICK  
   (  RowRef            INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY  
   ,  Facility          NVARCHAR(5)    NULL  
   ,  Storerkey         NVARCHAR(15)   NULL  
   ,  Sku               NVARCHAR(20)   NULL  
   ,  UOM               NVARCHAR(10)   NULL  
   ,  Lot               NVARCHAR(10)   NULL  
   ,  Loc               NVARCHAR(10)   NULL  
   ,  ID                NVARCHAR(18)   NULL  
   ,  DropID            NVARCHAR(20)   NULL  
   ,  UCCQty            INT            NULL  DEFAULT (0)  
   ,  Qty               INT            NULL  DEFAULT (0)  
   ,  PickMethod        NVARCHAR(10)   NULL  
   ,  LogicalFromLoc    NVARCHAR(10)   NULL  
   ,  FromLocType       NVARCHAR(10)   NULL  
   ,  FromPAZone        NVARCHAR(10)   NULL  
   ,  LocationHandling  NVARCHAR(10)   NULL      
   ,  LocationType      NVARCHAR(10)   NULL     
   ,  LocationCategory  NVARCHAR(10)   NULL  
   ,  ToLoc             NVARCHAR(10)   NULL  DEFAULT ('')  
   ,  Style             NVARCHAR(20)   NULL                         
   ,  Color             NVARCHAR(10)   NULL                         
   ,  Size              NVARCHAR(10)   NULL                         
   ,  Lottable01        NVARCHAR(18)   NULL   
   ,  TaskDetailKey     NVARCHAR(10)   NULL                        
   )  
  
   ------------------------------------------------------------------------------------  
   -- Getting PIckDetail for Release  
   ------------------------------------------------------------------------------------  
   INSERT INTO #TMP_PICK  
      (  Facility  
      ,  Storerkey  
      ,  Sku  
      ,  UOM  
      ,  Lot  
      ,  Loc  
      ,  ID  
      ,  DropID  
      ,  UCCQty  
      ,  Qty   
      ,  PickMethod    
      ,  LogicalFromLoc    
      ,  FromLocType   
      ,  FromPAZone    
      ,  LocationHandling    
      ,  LocationType        
      ,  LocationCategory  
      ,  Style               
      ,  Color              
      ,  Size    
      ,  Lottable01  
      ,  TaskDetailKey                                       
      )  
   SELECT LOC.Facility  
         ,PD.Storerkey  
         ,PD.Sku  
         ,PD.UOM  
         ,PD.Lot  
         ,PD.Loc  
         ,PD.ID  
         ,PD.DropID  
         ,UCCQty = ISNULL(UCC.Qty,0)  
         ,SUM(PD.Qty)    
         ,PickMethod  = CASE WHEN MIN(PD.PickMethod) = 'P' THEN 'FP'   
                             ELSE 'PP' END  
         ,LogicalFromLoc   = ISNULL(RTRIM(LOC.LogicalLocation),'')  
         ,FromLocType = CASE WHEN LOC.LocationType     <> 'DYNPPICK'   
                              AND LOC.LocationCategory <> 'SHELVING'   
                              AND SxL.LocationType NOT IN ('PICK','CASE')   
                              THEN 'BULK'   
                              ELSE 'DPP' END  
         ,FromPAZone       = ISNULL(RTRIM(LOC.PutawayZone),'')  
         ,LocationHandling = ISNULL(RTRIM(LOC.LocationHandling),'')  
         ,LocationType     = ISNULL(RTRIM(LOC.LocationType),'')  
         ,LocationCategory = ISNULL(RTRIM(LOC.LocationCategory),'')  
         ,Style = CASE WHEN PD.UOM = '6'                                        
                  THEN ISNULL(RTRIM(SKU.Style),'')                              
                  ELSE '' END                                                               
         ,Color = CASE WHEN PD.UOM = '6'                                        
                  THEN ISNULL(RTRIM(SKU.Color),'')                              
                  ELSE '' END                                                   
         ,Size  = CASE WHEN PD.UOM = '6'                                        
                  THEN ISNULL(RTRIM(SKU.Size),'')                               
                  ELSE '' END                                                   
         ,Lottable01 = ISNULL(RTRIM(LA.Lottable01),'')    
         ,TaskDetailKey = ISNULL(RTRIM(TD.TaskDetailkey),'')                                        
   FROM   WAVEDETAIL WD    WITH (NOLOCK)   
   JOIN   PICKDETAIL PD    WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)  
   JOIN   LOTATTRIBUTE LA  WITH (NOLOCK) ON (PD.Lot = LA.Lot)                   
   JOIN   LOC        LOC   WITH (NOLOCK) ON (PD.Loc = LOC.Loc)  
   JOIN   SKUxLOC    SxL   WITH (NOLOCK) ON (PD.Storerkey = SxL.Storerkey)  
                                         AND(PD.Sku = SxL.Sku)   
                                         AND(PD.Loc = SxL.Loc)  
   JOIN   SKU        SKU   WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)      
                                         AND(PD.Sku = SKU.Sku)                                         
   LEFT JOIN UCC     UCC   WITH (NOLOCK) ON (PD.DropID = UCC.UCCNo)  
                                         AND(UCC.Storerkey = @c_Storerkey)        
                                         AND(UCC.UCCNo <> '')                    
   LEFT JOIN TASKDETAIL TD WITH (NOLOCK) ON (PD.TaskDetailkey = TD.TaskdetailKey)
                                         AND(TD.Taskdetailkey <> '')             
                                         AND(TD.[Status] <> 'X')                 
   WHERE  WD.Wavekey = @c_Wavekey  
   GROUP BY LOC.Facility  
         ,  PD.Storerkey  
         ,  PD.Sku  
         ,  PD.UOM  
         ,  PD.Lot  
         ,  PD.Loc  
         ,  PD.ID  
         ,  PD.DropID  
         ,  ISNULL(UCC.Qty,0)  
         ,  ISNULL(RTRIM(LOC.LogicalLocation),'')  
         ,  CASE WHEN LOC.LocationType <> 'DYNPPICK'   
                  AND LOC.LocationCategory <> 'SHELVING'   
                  AND SxL.LocationType NOT IN ('PICK','CASE')   
                  THEN 'BULK'   
                  ELSE 'DPP' END  
         ,  ISNULL(RTRIM(LOC.PutawayZone),'')  
         ,  ISNULL(RTRIM(LOC.LocationHandling),'')  
         ,  ISNULL(RTRIM(LOC.LocationType),'')  
         ,  ISNULL(RTRIM(LOC.LocationCategory),'')  
         ,  CASE WHEN PD.UOM = '6'                                              
                 THEN ISNULL(RTRIM(SKU.Style),'')                               
                 ELSE '' END                                                    
         ,  CASE WHEN PD.UOM = '6'                                              
                 THEN ISNULL(RTRIM(SKU.Color),'')                               
                 ELSE '' END                                                    
         ,  CASE WHEN PD.UOM = '6'                                              
                 THEN ISNULL(RTRIM(SKU.Size),'')                                
                 ELSE '' END                                                    
         ,  ISNULL(RTRIM(LA.Lottable01),'')   
         ,  ISNULL(RTRIM(TD.TaskDetailkey),'')                                                              
   ORDER BY PD.UOM  
         ,  LocationType                                          
         ,  CASE WHEN PD.UOM = '6' THEN '' ELSE PD.Loc END                      
         ,  PD.Storerkey  
         ,  PD.Sku  
         ,  Style                                                               
         ,  Color                                                               
         ,  Size                                                                
         ,  Lottable01      
           
   IF NOT EXISTS ( SELECT 1 FROM #TMP_PICK TP WITH (NOLOCK)   
                 )  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_Err = 81010  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No Allocated Pick record found to release.  (ispRLWAV52_RPF)'  
      GOTO QUIT_SP  
   END     

   IF EXISTS ( SELECT 1 FROM #TMP_PICK TP WITH (NOLOCK)   
               WHERE UOM = '6'  
             )  
   BEGIN  
      INSERT INTO #TMP_LOC_DP  
         (  
         Facility  
      ,  Loc     
      ,  LocationType  
      ,  LocationHandling             
      ,  LocationCategory   
      ,  LogicalLocation                     
      ,  PickZone  
      ,  MaxPallet  
      )   
      SELECT  
         Facility  
      ,  Loc     
      ,  LocationType  
      ,  LocationHandling             
      ,  LocationCategory   
      ,  LogicalLocation                    
      ,  PickZone  
      ,  MaxPallet  
      FROM LOC WITH (NOLOCK)  
      WHERE Facility = @c_Facility  
      AND LocationType = 'DYNPICKP'  
   END  
  
   IF EXISTS ( SELECT 1 FROM #TMP_PICK TP WITH (NOLOCK)   
               WHERE UOM IN ('6', '7') AND FromLocType <> 'DPP'  
            )  
   BEGIN  
       INSERT INTO #TMP_LOC_DPP  
      (  
         Facility  
      ,  Loc     
      ,  LocationType  
      ,  LocationHandling             
      ,  LocationCategory   
      ,  LogicalLocation                     
      ,  PickZone  
      ,  MaxPallet  
      )   
      SELECT  
         Facility  
      ,  Loc     
      ,  LocationType  
      ,  LocationHandling             
      ,  LocationCategory   
      ,  LogicalLocation                    
      ,  PickZone  
      ,  MaxPallet  
      FROM LOC WITH (NOLOCK)  
      WHERE Facility = @c_Facility  
      AND LocationType = 'DYNPPICK'  
   END  
  
   SET @b_Success = 1  
   EXEC nspGetRight    
         @c_Facility              
      ,  @c_StorerKey               
      ,  ''         
      ,  'NKSPreCartonLevel'               
      ,  @b_Success        OUTPUT      
      ,  @c_PreCTNLevel    OUTPUT    
      ,  @n_err            OUTPUT    
      ,  @c_errmsg         OUTPUT  
  
   IF @b_Success <> 1  
   BEGIN   
      SET @n_Continue= 3      
      SET @n_Err     = 81020     
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing nspGetRight: '    
                     + '.(ispWAVNK01)'  
      GOTO QUIT_SP    
   END  
  
   SET @n_MinPalletCarton = 0  
   SET @c_MinPalletCarton = ''  
   SET @b_Success = 1  
   EXEC nspGetRight    
         @c_Facility              
      ,  @c_StorerKey               
      ,  ''         
      ,  'NKMinPalletCarton'               
      ,  @b_Success           OUTPUT      
      ,  @c_MinPalletCarton   OUTPUT    
      ,  @n_err               OUTPUT    
      ,  @c_errmsg            OUTPUT  
  
   IF @b_Success <> 1  
   BEGIN   
      SET @n_Continue= 3      
      SET @n_Err     = 81030     
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing nspGetRight - NKMinPalletCarton'    
                     + '.(ispWAVNK01)'  
      GOTO QUIT_SP    
   END  
  
   IF ISNUMERIC(@c_MinPalletCarton) = 1 AND @c_MinPalletCarton > '0'   
   BEGIN  
      SET @n_MinPalletCarton = CONVERT(INT, @c_MinPalletCarton)  
   END  
 
   SELECT @c_DispatchPiecePickMethod = w.DispatchPiecePickMethod        --(Wan02)
   FROM dbo.WAVE AS w WITH (NOLOCK)
   WHERE w.WaveKey = @c_Wavekey
   
   BEGIN TRAN  
   ------------------------------------------------------------------------------------  
   -- Calculate To Loc  
   ------------------------------------------------------------------------------------  
   DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT RowRef  
      ,  Facility  
      ,  Storerkey  
      ,  Sku  
      ,  UOM  
      ,  Lot  
      ,  Loc  
      ,  ID  
      ,  DropID  
      ,  UCCQty  
      ,  Qty   
      ,  PickMethod   
      ,  FromPAZone   
      ,  LogicalFromLoc                                                        
      ,  FromLocType                                                           
      ,  Lottable01    
      ,  TaskDetailkey                                                                                      
   FROM #TMP_PICK                                                              
   ORDER BY RowRef  
 
   OPEN CUR_PD  
     
   FETCH NEXT FROM CUR_PD INTO  @n_RowRef  
                              , @c_Facility  
                              , @c_Storerkey  
                              , @c_Sku  
                              , @c_UOM  
                              , @c_Lot  
                              , @c_FromLoc  
                              , @c_ID  
                              , @c_DropID  
                              , @n_UCCQty  
                              , @n_Qty  
                              , @c_PickMethod  
                              , @c_FromPAZone  
                              , @c_LogicalFromLoc                               
                              , @c_FromLocType                                  
                              , @c_Lottable01   
                              , @c_TaskDetailkey                                     
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
  
      SET @c_ToLoc = ''  
      SET @c_ToLocType = ''  
      SET @b_UpdMultiWave = 0                
      SET @b_DirectGenPickSlip = 0                      

      SELECT @c_SkuGroup = ISNULL(s.BUSR7,'')
      FROM dbo.SKU as s WITH (NOLOCK)
      WHERE s.Storerkey = @c_Storerkey
      AND   s.Sku = @c_Sku

      IF @c_FromLocType = 'DPP'  
      BEGIN  
         GOTO ADD_PSLIP -- Need to Generate Pickslipno  
      END  
  
      IF @c_UOM = '2' -- Single Order pick from Pallet Location  
      BEGIN  
         SELECT @c_ToLoc = c.UDF02  
         FROM CODELKUP c WITH (NOLOCK)    
         WHERE c.ListName = 'NikeLoc'  
         AND   c.Short = 'PPAST'                                              
         AND   c.Storerkey = @c_Storerkey
         AND   c.UDF01 = @c_SkuGroup  
  
         SET @c_ToLocType = 'PS'  -- Pack Station  
  
         GOTO ADD_TASK  
      END  

      SET @c_LocationHandling = CASE WHEN @c_Lottable01 = 'A' THEN '3'  
                                     WHEN @c_Lottable01 = 'B' THEN '4'  
                                     ELSE '3'  
                                     END  
      IF @c_UOM = '6'  
      BEGIN 
         SET @n_NoOfUCCInDP = 0 
         SELECT @n_NoOfUCCInDP = c.UDF04  
         FROM CODELKUP c WITH (NOLOCK)    
         WHERE c.ListName = 'SkuGroup'  
         AND   c.Code = @c_SkuGroup                                            
         AND   c.Storerkey = @c_Storerkey
          
         FIND_DP:  
            SET @c_LocationCategory = 'SHELVING'  
  
            SET @n_NoOfUCCSku      = 0  
            SET @n_TotatCartoninID = 0  

            SELECT @n_TotatCartoninID = COUNT(DISTINCT PD.DropID)  
                  ,@n_NoOfUCCSku = COUNT(DISTINCT UCC.Sku)  
            FROM WAVEDETAIL   WD  WITH (NOLOCK)  
            JOIN PICKDETAIL   PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)  
            JOIN UCC          UCC WITH (NOLOCK) ON (PD.DropID = UCC.UCCNo)  
                                      AND(UCC.Status > '1' AND UCC.Status < '6')  
            WHERE WD.Wavekey  = @c_Wavekey  
            AND   PD.UOM      = '6'  
            AND   PD.DropID   <>''  
            AND   PD.Status   < '5'  
            AND   PD.ID       = @c_ID  
            AND   PD.Storerkey= @c_Storerkey  
            AND   PD.Sku      = @c_Sku  

            IF @n_NoOfUCCSku = 1 AND @n_TotatCartonInID > @n_MinPalletCarton AND @n_MinPalletCarton > 0  
            BEGIN  
               SET @c_LocationCategory = 'BULK'  
            END  
  
            SET @c_SQL = N'SELECT TOP 1 @c_ToLoc = ISNULL(RTRIM(TD.ToLoc),'''')'                     
                       + ' FROM #TMP_LOC_DP  LOC WITH (NOLOCK)'                                    
                       + ' JOIN TASKDETAIL   TD  WITH (NOLOCK) ON (LOC.Loc = TD.ToLoc)'  
                       + ' JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (TD.Lot = LA.Lot)'  
                       + ' WHERE LOC.LocationType = ''DYNPICKP'''  
                       + ' AND   LOC.LocationHandling = @c_LocationHandling'    
                       + ' AND   LOC.LocationCategory = @c_LocationCategory'                                                
                       + ' AND   LOC.Facility = @c_Facility'  
                       + ' AND   TD.TaskType IN (''RPF'',''RP1'',''RPT'')'  
                       + ' AND   TD.UOM       = ''6'''  
                       + ' AND   TD.CaseID    <>''''' 
                       + ' AND   TD.Status    < ''9'''  
                       + ' AND   TD.SourceType like ''ispRLWAV52_RPF-%'''  
                       + ' AND   TD.Wavekey  = @c_Wavekey'  
                       + ' AND   TD.Storerkey= @c_Storerkey'
                       + CASE WHEN @c_SingleSkuPerDPLoc = 'N' THEN ''
                              ELSE ' AND TD.Sku = @c_Sku' END
                       + CASE WHEN @c_LocationCategory = 'BULK' THEN ''     
                              ELSE ' AND EXISTS (SELECT 1     
                                     FROM SKUxLOC SL WITH (NOLOCK)    
                                     JOIN LOC L WITH (NOLOCK) ON SL.loc = L.Loc                
                                     WHERE SL.Storerkey =  @c_Storerkey    
                                     AND   SL.Sku =  @c_Sku       
                                     AND   SL.locationType = ''PICK''      
                                     AND   L.LocationType = ''DYNPPICK''      
                                     AND   L.PickZone = LOC.PickZone    
                                     AND   L.LocationHandling = @c_LocationHandling    
                                     )' END      
                       + CASE WHEN @c_LocationCategory = 'BULK' THEN ''
                              ELSE ' GROUP BY TD.Storerkey, TD.ToLoc' END 
                       + CASE WHEN @c_LocationCategory = 'BULK' THEN ''
                              ELSE ' HAVING @n_NoOfUCCInDP > ISNULL(COUNT(DISTINCT TD.CaseID),0)' END 
                       + ' ORDER BY TD.ToLoc' 
            SET @c_SQLParms = N'@c_ToLoc              NVARCHAR(10) OUTPUT'
                            + ',@c_LocationHandling   NVARCHAR(10)'
                            + ',@c_LocationCategory   NVARCHAR(10)'
                            + ',@c_Facility           NVARCHAR(5)'
                            + ',@c_Wavekey            NVARCHAR(10)'
                            + ',@c_Storerkey          NVARCHAR(15)'
                            + ',@c_Sku                NVARCHAR(20)' 
                            + ',@n_NoOfUCCInDP        INT'  
                            
            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms 
                              ,@c_ToLoc               OUTPUT
                              ,@c_LocationHandling
                              ,@c_LocationCategory
                              ,@c_Facility        
                              ,@c_Wavekey         
                              ,@c_Storerkey       
                              ,@c_Sku
                              ,@n_NoOfUCCInDP                                           
                                                                                                                                                        
            --IF @c_LocationCategory = 'SHELVING'  
            --BEGIN  
            --   SELECT TOP 1 @c_ToLoc = ISNULL(RTRIM(TD.ToLoc),'')                     
            --   FROM #TMP_LOC_DP  LOC WITH (NOLOCK)                                    
            --   JOIN TASKDETAIL   TD  WITH (NOLOCK) ON (LOC.Loc = TD.ToLoc)  
            --   JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (TD.Lot = LA.Lot)  
            --   WHERE LOC.LocationType = 'DYNPICKP'  
            --   AND   LOC.LocationHandling = @c_LocationHandling    
            --   AND   LOC.LocationCategory = @c_LocationCategory                                                
            --   AND   LOC.Facility = @c_Facility  
            --   AND   TD.TaskType IN ('RPF','RP1','RPT')  
            --   AND   TD.UOM       = '6'  
            --   AND   TD.CaseID    <>''  
            --   AND   TD.Status    < '9'  
            --   AND   TD.SourceType like 'ispRLWAV52_RPF-%'  
            --   AND   TD.Wavekey  = @c_Wavekey  
            --   AND   TD.Storerkey= @c_Storerkey 
            --   AND   TD.Sku      = @c_Sku                --(Wan03)            
            --   AND EXISTS (SELECT 1     
            --               FROM SKUxLOC SL WITH (NOLOCK)    
            --               JOIN LOC L WITH (NOLOCK) ON SL.loc = L.Loc                
            --               WHERE SL.Storerkey =  @c_Storerkey    
            --               AND   SL.Sku =  @c_Sku       
            --               AND   SL.locationType = 'PICK'      
            --               AND   L.LocationType = 'DYNPPICK'      
            --               AND   L.PickZone = LOC.PickZone    
            --               AND   L.LocationHandling = @c_LocationHandling    
            --               )                   
            --   GROUP BY TD.Storerkey  
            --         ,  TD.ToLoc  
            --   HAVING @n_NoOfUCCInDP > ISNULL(COUNT( DISTINCT TD.CaseID),0)
            --   ORDER BY TD.ToLoc   
            --END  
            --ELSE  
            --BEGIN  
            --   SELECT TOP 1 @c_ToLoc = ISNULL(RTRIM(TD.ToLoc),'')  
            --   FROM #TMP_LOC_DP  LOC WITH (NOLOCK)                                  
            --   JOIN TASKDETAIL   TD  WITH (NOLOCK) ON (LOC.Loc = TD.ToLoc)  
            --   JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (TD.Lot = LA.Lot)  
            --   WHERE LOC.LocationType = 'DYNPICKP'  
            --   AND   LOC.LocationHandling = @c_LocationHandling    
            --   AND   LOC.LocationCategory = @c_LocationCategory                                                
            --   AND   LOC.Facility = @c_Facility  
            --   AND   TD.TaskType IN ('RPF','RP1','RPT')  
            --   AND   TD.UOM       = '6'  
            --   AND   TD.CaseID    <>''  
            --   AND   TD.Status    < '9'  
            --   AND   TD.FromID    = @c_ID  
            --   AND   TD.SourceType   like 'ispRLWAV52_RPF-%'  
            --   AND   TD.Wavekey  = @c_Wavekey  
            --   AND   TD.Storerkey= @c_Storerkey  
            --   AND   TD.Sku      = @c_Sku             --Wan03
            --END  
  
            IF @c_ToLoc = ''  
            BEGIN   
               GET_EMPTY_DP:  
  
               SET @c_LocationHandlings = '3'  
  
               IF @c_Lottable01 = 'B'  
               BEGIN  
                  SET @c_LocationHandlings = '3|4'  
               END  
  
               SET @c_DPPPKZone = ''  
               DECLARE CUR_DPP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT DPPPKZone = LOC.PickZone  
               FROM SKUxLOC WITH (NOLOCK)  
               JOIN #TMP_LOC_DPP  LOC WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)     
               JOIN dbo.fnc_DelimSplit ('|', @c_LocationHandlings) HLG           
                                          ON (HLG.ColValue = LOC.LocationHandling)   
               WHERE SKUxLOC.Storerkey= @c_Storerkey  
               AND   SKUxLOC.Sku      = @c_Sku  
               AND   SKUxLOC.LocationType = 'PICK'                              
               AND   LOC.LocationType = 'DYNPPICK'  
               AND   LOC.Facility     = @c_Facility  
               GROUP BY LOC.PickZone                                           
                     ,  LOC.LocationHandling                                    
                     ,  LOC.LogicalLocation                                    
                     ,  LOC.Loc                                                
               ORDER BY LOC.LocationHandling DESC                              
                     ,  LOC.LogicalLocation  
                     ,  LOC.Loc  
  
               OPEN CUR_DPP  
     
               FETCH NEXT FROM CUR_DPP INTO @c_DPPPKZone  
               WHILE @@FETCH_STATUS <> -1 AND @c_ToLoc = ''  
               BEGIN  
                  -- Find Last Logical location in DP that has stock  
                  IF NOT EXISTS (SELECT 1 FROM @t_DPRange WHERE PickZone = @c_DPPPKZone)  
                  BEGIN  
                     SET @c_logicalloc = ''           
                     SELECT TOP 1 @c_logicalloc = ISNULL(UDF01,'')          
                     FROM CODELKUP CL WITH (NOLOCK)           
                     WHERE CL.ListName = 'NKPHLDPLoc'          
                     AND   CL.Code = @c_DPPPKZone          
                     AND   CL.Storerkey = @c_Storerkey          
          
                     IF @c_logicalloc = ''          
                     BEGIN          
                        SET @c_logicalloc = ''          
                        SELECT DISTINCT TOP 1 @c_logicalloc = LOC.LogicalLocation          
                        FROM  #TMP_LOC_DP LOC WITH (NOLOCK)          
                        JOIN  LOTxLOCxID LLI WITH (NOLOCK)  ON (LLI.Loc = LOC.Loc AND  LLI.Storerkey = @c_Storerkey)                               
                        WHERE LOC.LocationType = 'DYNPICKP'          
                        AND   LOC.LocationHandling = @c_LocationHandling                            
                        AND   LOC.LocationCategory = @c_LocationCategory                             
                        AND   LOC.Facility = @c_Facility           
                        AND   LOC.PickZone = @c_DPPPKZone          
                        AND   (LLI.Qty - LLi.QtyPicked) + LLI.PendingMoveIN > 0          
                        ORDER BY LOC.LogicalLocation DESC          
                     END          
  
                     INSERT INTO @t_DPRange (PickZone, LogicalLocStart)  
                     VALUES (@c_DPPPKZone, @c_logicalloc)  
                  END  
                    
                  GET_PICKZONE_DP:                                                                                              
                  SET @n_LocQty = 0                                                                                             
                  SET @c_Logicalloc = ''                                                            
                  SET @c_LogicalLocStart = ''                                                                                   
                  SELECT TOP 1   @c_ToLoc = LOC.Loc  
                              ,  @c_Logicalloc = LOC.LogicalLocation                                                            
                              ,  @c_LogicalLocStart = LR.LogicalLocStart                                                        
                              ,  @n_LocQty = ISNULL(SUM((LLI.Qty - LLi.QtyPicked) + LLI.PendingMoveIN),0)    
                  FROM  #TMP_LOC_DP  LOC WITH (NOLOCK)  
                  JOIN  @t_DPRange   LR  ON (LOC.PickZone = LR.PickZone)                                                            
                  LEFT JOIN  LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.Loc = LOC.Loc AND  LLI.Storerkey = @c_Storerkey)                                    
                  WHERE LOC.LocationType = 'DYNPICKP'  
                  AND   LOC.LocationHandling = @c_LocationHandling                    
                  AND   LOC.LocationCategory = @c_LocationCategory                  
                  AND   LOC.Facility = @c_Facility   
                  AND   LOC.PickZone = @c_DPPPKZone  
                  AND   LOC.LogicalLocation > LR.LogicalLocStart  
                  GROUP BY LOC.LogicalLocation, LOC.Loc, LR.LogicalLocStart  
                  ORDER BY LOC.LogicalLocation  
                          ,LOC.Loc  
  
                  IF @c_Toloc = '' AND @c_LogicalLocStart = ''  
                  BEGIN  
                     SELECT @c_LogicalLocStart =  LogicalLocStart   
                     FROM @t_DPRange WHERE PickZone = @c_DPPPKZone  
                  END  
  
                  IF @c_Toloc = '' AND @c_LogicalLocStart = ''  
                  BEGIN  
                     GOTO NEXT_DPPPKZone  
                  END   
  
                  IF @c_Toloc = '' AND @c_LogicalLocStart <> ''  -- Last Loc, Search empty from begining  
                  BEGIN  
                     UPDATE @t_DPRange SET LogicalLocStart = '' WHERE PickZone = @c_DPPPKZone  
                     GOTO GET_PICKZONE_DP  
                  END  
  
                  IF @n_LocQty = 0   
                  BEGIN   
                     UPDATE @t_DPRange SET LogicalLocStart = @c_logicalloc WHERE PickZone = @c_DPPPKZone  
                  END  
                  ELSE  
                  BEGIN   
                     SET @c_Toloc = ''  
                  END  
  
                  NEXT_DPPPKZone:                                                                             
                  FETCH NEXT FROM CUR_DPP INTO @c_DPPPKZone  
               END  
               CLOSE  CUR_DPP  
               DEALLOCATE CUR_DPP  
            END   
  
            IF @c_ToLoc = ''  
            BEGIN   
               SET @n_Continue = 3  
            END  
  
            SET @c_ToLocType = 'DP'     
            GOTO ADD_TASK  
      END  
        
      FIND_DPP: -- UOM = '7'  

         IF @c_TaskDetailKey <> ''  
         BEGIN  
            SET @b_DirectGenPickSlip = 1           
            GOTO ADD_PSLIP  
         END  

  
         SET @c_ToLocType = 'DPP'  
         -- Find Sku in DPP Loc  

         IF @c_Lottable01 = 'B'                                                 
         BEGIN  
            --3) Find loc or pending move in loc with same sku   
            SELECT TOP 1 @c_ToLoc = LOC.Loc  
            FROM LOTxLOCxID   LLI WITH (NOLOCK)  
            JOIN #TMP_LOC_DPP LOC WITH (NOLOCK) ON (LLI.Loc = LOC.Loc)  
            WHERE LLI.Storerkey= @c_Storerkey  
            AND   LLI.Sku = @c_Sku    
            AND   LLI.Qty + LLI.PendingMoveIN > 0                              
            AND   LOC.LocationCategory = 'SHELVING'  
            AND   LOC.LocationType = 'DYNPPICK'  
            AND   LOC.LocationHandling = @c_LocationHandling                     
            AND   LOC.Facility = @c_Facility  
            ORDER BY LOC.LogicalLocation  
                  ,  LOC.Loc  
         END  
  
         IF @c_ToLoc = ''  
         BEGIN  
            --4) Ops Pre-defined Loc for Sku. Find pick face loc setup in skuxloc only   
            SELECT TOP 1 @c_ToLoc = LOC.Loc  
            FROM SKUxLOC SxL  WITH (NOLOCK)  
            JOIN #TMP_LOC_DPP LOC WITH (NOLOCK) ON (SxL.Loc = LOC.Loc)  
            LEFT JOIN  LOTxLOCxID LLI WITH (NOLOCK)  ON  (LLI.Loc = LOC.Loc)   
                                                     AND (LLI.Storerkey = @c_Storerkey)  
                                                     AND (LLI.Sku = @c_Sku)   
            WHERE SxL.Storerkey= @c_Storerkey  
            AND   SxL.Sku = @c_Sku    
            AND   SxL.LocationType = 'PICK'                                     
            AND   LOC.Facility = @c_Facility  
            AND   LOC.LocationCategory = 'SHELVING'  
            AND   LOC.LocationType = 'DYNPPICK'  
            AND   LOC.LocationHandling = @c_LocationHandling   
            ORDER BY LOC.LogicalLocation  
                  ,  LOC.Loc  
         END  
  
         IF @c_Lottable01 = 'B' AND @c_ToLoc = ''                                                                                                 
         BEGIN  
            DECLARE CUR_DPP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DPPPKZone = LOC.PickZone  
            FROM SKUxLOC WITH (NOLOCK)  
            JOIN #TMP_LOC_DPP LOC WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
            WHERE SKUxLOC.Storerkey= @c_Storerkey  
            AND   SKUxLOC.Sku      = @c_Sku  
            AND   SKUxLOC.LocationType = 'PICK'    
            AND   LOC.LocationType = 'DYNPPICK'  
            AND   LOC.LocationHandling IN ( '3', '4' )  
            AND   LOC.Facility     = @c_Facility  
            GROUP BY LOC.PickZone  
                  ,  LOC.LocationHandling  
                  ,  LOC.LogicalLocation                                      
                  ,  LOC.Loc   
            ORDER BY LOC.LocationHandling DESC  
                  ,  LOC.LogicalLocation  
                  ,  LOC.Loc  
  
            OPEN CUR_DPP  
     
            FETCH NEXT FROM CUR_DPP INTO @c_DPPPKZone  
            WHILE @@FETCH_STATUS <> -1 AND @c_ToLoc = ''  
            BEGIN  
               SELECT TOP 1 @c_ToLoc = LOC.Loc  
               FROM #TMP_LOC_DPP LOC WITH (NOLOCK)                                                                   
               LEFT JOIN  LOTxLOCxID LLI WITH (NOLOCK)  ON (LLI.Loc = LOC.Loc AND  LLI.Storerkey = @c_Storerkey)       
               WHERE LOC.LocationCategory = 'SHELVING'  
               AND   LOC.LocationType = 'DYNPPICK'  
               AND   LOC.LocationHandling = @c_LocationHandling  
               AND   LOC.Facility = @c_Facility   
               AND   LOC.PickZone = @c_DPPPKZone   
               AND   LLI.Storerkey IS NULL  
               GROUP BY LOC.LogicalLocation, LOC.Loc  
               HAVING CASE WHEN ISNULL(SUM((LLI.Qty - LLi.QtyPicked) + LLI.PendingMoveIN),0) = 0 THEN 0  
                                       ELSE COUNT(1)  
                                       END  = 0   
               ORDER BY LOC.LogicalLocation  
                     ,  LOC.Loc  
    
               FETCH NEXT FROM CUR_DPP INTO @c_DPPPKZone  
            END  
            CLOSE CUR_DPP  
            DEALLOCATE CUR_DPP  
         END  
  

         IF @c_FromLocType <> 'DPP' AND @c_DropID <> '' AND @c_ToLoc <> ''  
         BEGIN  
            SET @b_UpdMultiWave = 1              
  
            DELETE FROM @t_UPDPICK  
  
            INSERT INTO @t_UPDPICK  
               (    
                  t.PickDetailKey   
               ,  t.Loadkey    
               ,  t.Orderkey    
               ,  t.Consigneekey    
               ,  t.[Route]    
               ,  t.ExternOrderkey   
               ,  t.Wavekey   
               ,  t.Qty             
               )  
            SELECT PD.PickDetailKey    
                  ,OH.Loadkey    
                  ,OH.Orderkey    
                  ,Consigneekey = ISNULL(RTRIM(OH.Consigneekey),'')    
                  ,Route = ISNULL(RTRIM(OH.Route),'')    
                  ,ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')    
                  ,WD.Wavekey   
                  ,PD.Qty                                        
            FROM WAVEDETAIL WD WITH (NOLOCK)                                            
            JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)              
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = OH.Orderkey)     
            LEFT JOIN TASKDETAIL TD WITH (NOLOCK) ON (PD.Taskdetailkey = TD.TaskdetailKey)    
                                                  AND(TD.TaskDetailkey <> '')    
                                                  AND(TD.[Status] <> 'X')                          
            WHERE PD.Lot = @c_Lot    
            AND   PD.Loc = @c_FromLoc    
            AND   PD.ID  = @c_Id    
            AND   PD.UOM = @c_UOM    
            AND   PD.DropID = @c_DropID                                              
            AND   PD.[Status] < '9'      
            AND   TD.TaskDetailkey IS NULL    
            ORDER BY PD.PickDetailKey  
              
            SELECT @n_Qty = ISNULL(SUM(Qty),0)                                   
            FROM @t_UPDPICK  
         END  
  
      ADD_TASK:  
  
         IF @c_ToLoc = '' AND @c_UOM <> '6'    
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 81040  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)  
                         +': ' + CASE WHEN @c_UOM = '2' THEN 'Pack Station' ELSE 'DPP Location for Sku: ' + @c_Sku END  
                         + ' Not found. (ispRLWAV52_RPF)'  
            GOTO QUIT_SP  
         END  
    
         IF @c_ToLoc <> ''          
         BEGIN  
            UPDATE #TMP_PICK  
            SET ToLoc = @c_ToLoc  
            WHERE RowRef = @n_RowRef  
  
            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_Err = 81050   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (ispRLWAV52_RPF)'   
               GOTO QUIT_SP  
            END                     
            ------------------------------------------------------------------------------------  
            -- Create TaskDetail (START)  
            ------------------------------------------------------------------------------------  
            SET @c_TaskDetailkey = ''  
            SET @c_TaskType = 'RPF'  
  
            SET @b_success = 1    
            EXECUTE nspg_getkey    
                  'TaskDetailKey'   
                  , 10    
                  , @c_taskdetailkey OUTPUT    
                  , @b_success   OUTPUT    
                  , @n_err       OUTPUT    
                  , @c_errmsg    OUTPUT  
                   
            IF NOT @b_success = 1    
            BEGIN    
               SET @n_Continue = 3  
               GOTO QUIT_SP    
            END    
   
            SET @c_SourceType = 'ispRLWAV52_RPF-' + RTRIM(@c_DispatchPiecePickMethod)  
  
            SET @c_LogicalToLoc = @c_ToLoc  
  
            SET @c_TransitLoc = ''  
            SET @c_FinalLoc = ''  
            SET @c_FinalID = '' 
             
            IF @c_ToLocType = 'PS' AND @c_TaskType = 'RPF'              
               SET @c_TransitLoc = @c_Toloc  
            ELSE IF @c_ToLocType IN('DP','DPP') AND @c_TaskType = 'RPF'  
            BEGIN  
               SELECT @c_TransitLoc = PICKZONE.InLoc  
               FROM LOC (NOLOCK)  
               JOIN PICKZONE (NOLOCK) ON LOC.Pickzone = PICKZONE.Pickzone  
               WHERE LOC.Loc = @c_Toloc  
                 
               IF @c_TransitLoc IS NULL  
                  SET @c_TransitLoc = ''  
                 
               SET @c_FinalLoc = @c_LogicalToLoc  
               SET @c_FinalID = @c_ID                                               
            END      
              
            INSERT TASKDETAIL    
               (    
                  TaskDetailKey    
               ,  TaskType    
               ,  Storerkey    
               ,  Sku    
               ,  UOM    
               ,  UOMQty    
               ,  Qty    
               ,  SystemQty  
               ,  Lot    
               ,  FromLoc    
               ,  FromID    
               ,  ToLoc    
               ,  ToID    
               ,  SourceType    
               ,  SourceKey    
               ,  Priority    
               ,  SourcePriority    
               ,  Status    
               ,  LogicalFromLoc    
               ,  LogicalToLoc    
               ,  PickMethod  
               ,  Wavekey  
               ,  Message02   
               ,  Areakey  
               ,  Message03  
               ,  Caseid  
               ,  Loadkey  
               ,  PendingMoveIn                                                       
               ,  TransitLoc                               
               ,  FinalLoc          
               ,  FinalID                           
               )    
               VALUES    
               (    
                  @c_taskdetailkey    
               ,  @c_TaskType       --Tasktype    
               ,  @c_Storerkey    
               ,  @c_Sku    
               ,  @c_UOM            -- UOM,    
               ,  @n_UCCQty         -- UOMQty,    
               ,  @n_UCCQty         --Qty  
               ,  @n_Qty            --systemqty  
               ,  @c_Lot     
               ,  @c_Fromloc     
               ,  @c_ID             -- from id    
               ,  @c_Toloc          
               ,  @c_ID             -- to id    
               ,  @c_SourceType     --Sourcetype    
               ,  @c_Wavekey        --Sourcekey    
               ,  '5'               -- Priority    
               ,  '9'               -- Sourcepriority    
               ,  '0'               -- Status    
               ,  @c_LogicalFromLoc --Logical from loc    
               ,  @c_LogicalToLoc   --Logical to loc    
               ,  @c_PickMethod  
               ,  @c_Wavekey  
               ,  @c_ToLocType  
               ,  ''  
               ,  ''  
               ,  @c_DropID  
               ,  ''  
               ,  CASE WHEN @c_UOM IN ('2') THEN 0 ELSE @n_UCCQty END             
               ,  @c_TransitLoc
               ,  @c_FinalLoc 
               ,  @c_FinalID 
               )  
      
            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_Err = 81060   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV52_RPF)'   
               GOTO QUIT_SP  
            END     
         END  
         ------------------------------------------------------------------------------------  
         -- Create TaskDetail (END)  
         ------------------------------------------------------------------------------------  
      ADD_PSLIP:  
  
         ------------------------------------------------------------------------------------  
         -- Stamp TaskDetailKey & Wavekey to PickDetail, Generate Pickslipno (START)  
         ------------------------------------------------------------------------------------  
         IF @b_UpdMultiWave = 1                                             
         BEGIN  
            DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT t.PickDetailKey  
                  ,t.Loadkey  
                  ,t.Orderkey  
                  ,t.Consigneekey    
                  ,t.[Route]  
                  ,t.ExternOrderkey    
                  ,t.Wavekey   
            FROM @t_UPDPICK t  
            ORDER BY RowRef       
         END  
       
         ELSE IF @b_DirectGenPickSlip = 1           
         BEGIN          
            DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
            SELECT PD.PickDetailKey            
                  ,OH.Loadkey            
                  ,OH.Orderkey            
                  ,Consigneekey = ISNULL(RTRIM(OH.Consigneekey),'')            
                  ,Route = ISNULL(RTRIM(OH.Route),'')            
                  ,ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')            
                  ,WD.Wavekey                                          
            FROM WAVEDETAIL WD WITH (NOLOCK)                                  
            JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)                      
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = OH.Orderkey)                      
            WHERE PD.Lot = @c_Lot            
            AND   PD.UOM = @c_UOM            
            AND   PD.DropID = @c_DropID            
            AND   WD.Wavekey= @c_Wavekey                                                         
            AND   PD.[Status] < '9'                                                                            
         END          
         ELSE  
         BEGIN  
            DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PD.PickDetailKey  
                  ,OH.Loadkey  
                  ,OH.Orderkey  
                  ,Consigneekey = ISNULL(RTRIM(OH.Consigneekey),'')  
                  ,Route = ISNULL(RTRIM(OH.Route),'')  
                  ,ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')  
                  ,WD.Wavekey                                       
            FROM WAVEDETAIL WD WITH (NOLOCK)                                          
            JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)            
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (PD.Orderkey = OH.Orderkey)            
            WHERE PD.Lot = @c_Lot  
            AND   PD.Loc = @c_FromLoc  
            AND   PD.ID  = @c_Id  
            AND   PD.UOM = @c_UOM  
            AND   PD.DropID = @c_DropID  
            AND   WD.Wavekey= @c_Wavekey                                               
            AND   PD.[Status] < '9'                                                                  
         END  
  
         OPEN CUR_UPD  
  
         FETCH NEXT FROM CUR_UPD INTO  @c_PickDetailKey  
                                    ,  @c_Loadkey  
                                    ,  @c_Orderkey  
                                    ,  @c_Consigneekey  
                                    ,  @c_Route  
                                    ,  @c_ExternOrderkey         
                                    ,  @c_Wavekey_PD             
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            SET @c_PickSlipNo = ''  
  
            SET @c_Zone = '3'                
            SET @c_PackOrderkey = @c_Orderkey    
  
            IF @c_PreCTNLevel = 'L'         
            BEGIN  
               SELECT @c_PickSlipNo = PickHeaderKey  
               FROM PICKHEADER WITH (NOLOCK)  
               WHERE ExternOrderkey = @c_Loadkey  
               AND   Loadkey  = @c_Loadkey  
               AND   Orderkey = ''  
               AND   Zone     = '7'  
               AND   Wavekey  = @c_Wavekey  
  
               SET @c_Zone = '7'  
               SET @c_PackOrderkey = ''  
               SET @c_ExternOrderkey = ''   
            END  
            ELSE IF @c_Orderkey <> ''          
            BEGIN  
               SELECT @c_PickSlipNo = PickHeaderKey  
               FROM PICKHEADER WITH (NOLOCK)  
               WHERE ExternOrderkey = @c_Loadkey  
               AND   Orderkey = @c_Orderkey  
               AND   Zone     = '3'  
            END  
  
            IF @c_Orderkey <> '' AND @c_PickSlipNo = ''   
            BEGIN  
               SET @b_success = 1    
               EXECUTE nspg_getkey    
                     'PickSlip'    
                     , 9    
                     , @c_PickSlipNo   OUTPUT    
                     , @b_success      OUTPUT    
                     , @n_err          OUTPUT    
                     , @c_errmsg       OUTPUT  
                   
               IF NOT @b_success = 1    
               BEGIN    
                  SET @n_continue = 3  
                  GOTO QUIT_SP    
               END    
   
               SET @c_Pickslipno = 'P' + @c_Pickslipno  
  
               INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Loadkey, Wavekey, Storerkey)     
               VALUES (@c_Pickslipno , @c_LoadKey, @c_PackOrderkey, '0', @c_Zone, @c_Loadkey, @c_Wavekey, @c_Storerkey)        
                 
               SET @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN  
                  SET @n_continue = 3    
                  SET @n_Err = 81070   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed. (ispRLWAV52_RPF)'   
                  GOTO QUIT_SP  
               END     
  
               INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)    
               VALUES (@c_Pickslipno , NULL, NULL, NULL)   
  
               SET @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN  
                  SET @n_continue = 3    
                  SET @n_Err = 81080   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO Failed. (ispRLWAV52_RPF)'   
                  GOTO QUIT_SP  
               END     
  
               IF @c_DispatchPiecePickMethod = 'DTC'     --IF DTC, DO NOT UPDATE PICKSLIP TO Pickdetail & Insert PACKHEADER, PACKHEADER Insert At ECOM PAcking    
               BEGIN   
                  SET @c_PickSlipNo = ''  
               END  
               ELSE  
               BEGIN  
                  INSERT INTO PACKHEADER (PickSlipNo, Storerkey, Orderkey, Loadkey, Consigneekey, Route, OrderRefNo )    
                  VALUES (@c_Pickslipno , @c_Storerkey, @c_PackOrderkey, @c_Loadkey, @c_Consigneekey, @c_Route, @c_ExternOrderkey)    
  
                  SET @n_err = @@ERROR    
                  IF @n_err <> 0    
                  BEGIN  
                     SET @n_continue = 3    
                     SET @n_Err = 81090   
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKHEADER Failed. (ispRLWAV52_RPF)'   
                     GOTO QUIT_SP  
                  END           
               END  
            END  
  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET TaskDetailKey = CASE WHEN @c_FromLocType = 'DPP' THEN  
                                     ''  
                                     ELSE @c_Taskdetailkey END    
               ,Wavekey       = @c_Wavekey_PD--@c_Wavekey   --(Wan10)  
               ,PickSlipNo    = @c_PickSlipNo  
               ,TrafficCop    = NULL  
               ,EditWho = SUSER_SNAME()  
               ,EditDate= GETDATE()  
            WHERE PickDetailkey = @c_PickDetailKey  
  
            SET @n_err = @@ERROR  
            IF @n_err <> 0   
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 81100     
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV52_RPF)'   
               GOTO QUIT_SP  
            END   
  
            FETCH NEXT FROM CUR_UPD INTO  @c_PickDetailKey  
                                       ,  @c_Loadkey  
                                       ,  @c_Orderkey  
                                       ,  @c_Consigneekey  
                                       ,  @c_Route  
                                       ,  @c_ExternOrderkey         
                                       ,  @c_Wavekey_PD             
                                      
         END              
         CLOSE CUR_UPD  
         DEALLOCATE CUR_UPD  
         ------------------------------------------------------------------------------------  
         -- Stamp TaskDetailKey & Wavekey to PickDetail, Generate Pickslipno (END)  
         ------------------------------------------------------------------------------------  
      SET @c_UOM_Prev = @c_UOM  
  
      FETCH NEXT FROM CUR_PD INTO  @n_RowRef  
                                 , @c_Facility  
                                 , @c_Storerkey  
                                 , @c_Sku  
                                 , @c_UOM  
                                 , @c_Lot  
                                 , @c_FromLoc  
                                 , @c_ID  
                                 , @c_DropID  
                                 , @n_UCCQty  
                                 , @n_Qty  
                                 , @c_PickMethod  
                                 , @c_FromPAZone  
                                 , @c_LogicalFromLoc                            
                                 , @c_FromLocType                               
                                 , @c_Lottable01   
                                 , @c_TaskDetailkey    --(Wan11)                                   
  
      IF @n_Continue = 3 AND @c_UOM_Prev = '6' AND (@c_UOM <> '6' OR @@FETCH_STATUS = -1)   
      BEGIN  
         SET @n_UCCWODPLoc = 0  
         SET @n_UCCWOBULKDPLoc = 0  
         SELECT @n_UCCWOBULKDPLoc = SUM(CASE WHEN @n_MinPalletCarton > 0 THEN T.TotalCartonInID ELSE 0 END)  
               ,@n_UCCWODPLoc = SUM(CASE WHEN @n_MinPalletCarton = 0 THEN T.TotalCartonInID ELSE 0 END)  
         FROM (  
            SELECT ID  
                  ,TotalCartonInID = COUNT(DISTINCT DropID)    
            FROM #TMP_PICK  
            WHERE UOM = '6'    
            AND ToLoc = ''  
            GROUP BY ID        
            ) T  
  
         SET @n_Err = 81110  
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not enough DP Location. '  
                      +'No of UCC: ' + CONVERT(NVARCHAR(5),@n_UCCWODPLoc) + ' still need(s) Shelving DP Loc, '  
                      +'No of UCC: ' + CONVERT(NVARCHAR(5),@n_UCCWOBULKDPLoc) + ' still need(s) BULK DP Loc (ispRLWAV52_RPF)'  
         GOTO QUIT_SP  
      END  
   END  
   CLOSE CUR_PD  
   DEALLOCATE CUR_PD  
      
   ------------------------------------------------------------------------------------  
   -- Update Loose Qty From Pallet Loc's PickMethod to 'FP' if all UCC go to same toloc  
   ------------------------------------------------------------------------------------  
  
   DECLARE CUR_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT TD.FromLoc  
      ,   TD.FromID  
      ,   ToLoc   = MIN(TD.ToLoc)  
      ,   NoOfUCC_Replen = COUNT(DISTINCT TD.CaseID)  
   FROM TASKDETAIL TD  WITH (NOLOCK)  
   JOIN LOC        LOC WITH (NOLOCK) ON (TD.FromLoc = LOC.Loc)  
   WHERE TD.Wavekey = @c_Wavekey  
   AND   TD.PickMethod        = 'PP'  
   AND   TD.FromID            <>''  
   AND   LOC.LocationHandling = '1'   
   AND   LOC.LocationType     = 'OTHER'      
   AND   LOC.LocationCategory = 'BULK'   
   GROUP BY TD.FromLoc  
         ,  TD.FromID  
   HAVING COUNT ( DISTINCT TD.Sku )   = 1  
   AND    COUNT ( DISTINCT TD.ToLoc ) = 1  
   ORDER BY TD.FromLoc  
         ,  TD.FromID  
  
   OPEN CUR_ID  
     
   FETCH NEXT FROM CUR_ID INTO  @c_FromLoc  
                              , @c_ID  
                              , @c_ToLoc  
                              , @n_NoOfUCC_Replen  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF (  SELECT COUNT(DISTINCT UCCNo)   
            FROM UCC WITH (NOLOCK)  
            WHERE Loc = @c_FromLoc  
            AND   ID  = @c_ID  
            AND   Status <= '3'  
         ) <> @n_NoOfUCC_Replen  
      BEGIN  
         GOTO NEXT_ID  
      END  
  
      SET @CUR_UPDPM = CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT TD.TaskDetailKey  
      FROM TASKDETAIL TD  WITH (NOLOCK)  
      WHERE TD.Wavekey = @c_Wavekey  
      AND   TD.FromLoc = @c_FromLoc  
      AND   TD.ToID    = @c_ID  
      ORDER BY TD.TaskDetailKey  
  
      OPEN @CUR_UPDPM        
  
      FETCH NEXT FROM @CUR_UPDPM INTO @c_TaskDetailKey  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         UPDATE TASKDETAIL WITH (ROWLOCK)  
            SET PickMethod = 'FP'  
         WHERE TaskDetailKey = @c_TaskDetailKey  
  
         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_Err = 81120   
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TASKDETAIL Failed. (ispRLWAV52_RPF)'   
            GOTO QUIT_SP  
         END   
         FETCH NEXT FROM @CUR_UPDPM INTO @c_TaskDetailKey  
      END  
        
      NEXT_ID:  
      FETCH NEXT FROM CUR_ID INTO  @c_FromLoc  
                                 , @c_ID  
                                 , @c_ToLoc  
                                 , @n_NoOfUCC_Replen  
   END  
   CLOSE CUR_ID  
   DEALLOCATE CUR_ID  
  
   -------------------------------------------------------------------------------------  
   -- Replenishment - START Enable Gen General replenishment task  
   -------------------------------------------------------------------------------------  
   DECLARE @n_RemainingQty INT = 0  
         , @n_Severity     INT = 0  
  
         , @CUR_SxL        CURSOR  
         , @CUR_REPLUCC    CURSOR  
  
  
   IF OBJECT_ID('tempdb..#UCCPAlloc','u') IS NOT NULL  
      DROP TABLE #UCCPAlloc;  
  
   CREATE TABLE #UCCPAlloc   
   (  SeqNo             INT IDENTITY(1, 1)  PRIMARY Key  
   ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT ('')   
   ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT ('')   
   ,  UCCNo             NVARCHAR(20)   NOT NULL DEFAULT ('')   
   ,  UCCQtyAvail       INT            NOT NULL DEFAULT (0)   
   )  
  
   IF OBJECT_ID('tempdb..#UCCRepl','u') IS NOT NULL  
      DROP TABLE #UCCRepl;  
  
   CREATE TABLE #UCCRepl   
   (  SeqNo             INT IDENTITY(1, 1)  PRIMARY Key  
   ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT ('')   
   ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT ('')   
   ,  UCCNo             NVARCHAR(20)   NOT NULL DEFAULT ('')   
   ,  UCCReplQty        INT            NOT NULL DEFAULT (0)   
   )  
  
   INSERT INTO #UCCPAlloc ( Storerkey, Sku, UCCNo, UCCQtyAvail )  
   SELECT   
          UCC.Storerkey  
         ,UCC.Sku  
         ,UCC.UCCNo    
         ,UCCQtyAvail = UCC.Qty - ISNULL(SUM(PD.Qty),0)  
   FROM (SELECT DISTINCT Storerkey, Sku FROM #TMP_PICK) S   
   JOIN PICKDETAIL PD (NOLOCK) ON  PD.Storerkey = S.Storerkey  
                               AND PD.Sku = S.Sku  
   JOIN UCC WITH (NOLOCK) ON  UCC.UCCNo = PD.DropID  
   JOIN LOC L WITH (NOLOCK) ON L.Loc = PD.Loc    
   WHERE UCC.[Status] = '3'  
   AND   UCC.UCCNo <> ''  
   AND   PD.[Status] <= '3' -- Close pallet (to intransit or home location not update pickdetail.status to '5')  
   AND   PD.UOM = '7'  
   AND   PD.DropID <> ''  
   AND   L.Facility = @c_Facility  
   AND   L.LocationType NOT IN ('DYNPPICK')     -- Not In Home loc  
   AND   L.LocationCategory NOT IN ('SHELVING') -- Not In Home loc  
   GROUP BY UCC.Storerkey  
         ,  UCC.Sku  
         ,  UCC.UCCNo    
         ,  UCC.Qty  
  
   INSERT INTO #UCCRepl ( Storerkey, Sku, UCCNo, UCCReplQty )  
   SELECT   
          UCC.Storerkey  
         ,UCC.Sku  
         ,UCC.UCCNo    
         ,UCC.Qty  
   FROM (SELECT DISTINCT Storerkey, Sku FROM #TMP_PICK) S   
   JOIN UCC WITH (NOLOCK) ON  UCC.Storerkey = S.Storerkey  
                          AND UCC.Sku = S.Sku  
   JOIN LOC L WITH (NOLOCK) ON L.Loc = UCC.Loc    
   WHERE UCC.[Status] = '1'   
   AND   UCC.UCCNo <> ''  
   AND   L.Facility = @c_Facility  
   AND   EXISTS (SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK) WHERE TD.CaseID = UCC.UCCNo AND TD.[Status] < '9')  
   AND   NOT EXISTS (SELECT 1 FROM #UCCPAlloc AL WHERE AL.UCCNo = UCC.UCCNo)  
  
   SET @CUR_SxL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT SxL.Storerkey  
      ,  SxL.Sku  
      ,  SxL.Loc  
      ,  Severity = SxL.QtyLocationLimit - ((SxL.Qty - SxL.QtyAllocated - SxL.QtyPicked) + ISNULL(SUM(AL.UCCQtyAvail),0) + ISNULL(SUM(RP.UCCReplQty),0))  
      ,  L.LocationHandling  
   FROM (SELECT T.Storerkey, T.Sku FROM #TMP_PICK T GROUP BY T.Storerkey, T.Sku)  PD  
   JOIN SKUxLOC SxL WITH (NOLOCK) ON  PD.Storerkey = SxL.Storerkey AND PD.Sku = SxL.Sku  
   JOIN LOC L WITH (NOLOCK) ON SxL.Loc = L.Loc  
   LEFT JOIN #UCCPAlloc AL  ON  PD.Storerkey = AL.Storerkey  AND PD.Sku = AL.Sku  
   LEFT JOIN #UCCREPL   RP  ON  PD.Storerkey = RP.Storerkey  AND PD.Sku = RP.Sku  
   WHERE SxL.LocationType = 'PICK'  
   AND   SxL.QtyLocationMinimum > 0  
   AND   SxL.QtyLocationLimit > 0      
   AND   L.Facility = @c_Facility  
   AND   L.LocationType = 'DYNPPICK'  
   AND   L.LocationCategory = 'SHELVING'       
   AND   L.LocationFlag NOT IN ('DAMAGE', 'HOLD')     
   AND   L.[Status] = 'OK'   
   GROUP BY  
         SxL.Storerkey  
      ,  SxL.Sku  
      ,  SxL.Loc  
      ,  SxL.QtyLocationLimit   
      ,  SxL.Qty  
      ,  SxL.QtyAllocated  
      ,  SxL.QtyPicked  
      ,  SxL.QtyLocationMinimum  
      ,  L.LocationHandling  
   HAVING (SxL.Qty - SxL.QtyAllocated - SxL.QtyPicked)  + ISNULL(SUM(AL.UCCQtyAvail),0) + ISNULL(SUM(RP.UCCReplQty),0) <= SxL.QtyLocationMinimum                                                                     
   ORDER BY Sku  
     
   OPEN @CUR_SxL  
   FETCH NEXT FROM @CUR_SxL INTO @c_Storerkey  
         ,  @c_Sku  
                              ,  @c_ToLoc  
                              ,  @n_Severity  
                              ,  @c_LocationHandling  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @n_RemainingQty = @n_Severity  

      SET @c_Lot     = ''   
      SET @c_FromLoc = ''  
      SET @c_ID      = ''  
      SET @c_DropID  = ''  
      SET @n_UCCQty  = 0  
  
      SET @CUR_REPLUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT   LLI.Lot  
            ,  LLI.Loc  
            ,  LLI.ID  
            ,  CS.UCCNo  
            ,  CS.UCCQty  
            ,  LOC.LogicalLocation  
      FROM LOTxLOCxID LLI WITH (NOLOCK)        
      JOIN LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC AND LOC.Status <> 'HOLD')    
      JOIN ID  WITH (NOLOCK) ON (LLI.Id  = ID.ID   AND ID.STATUS <> 'HOLD')    
      JOIN LOT WITH (NOLOCK) ON (LLI.LOT = LOT.LOT AND LOT.STATUS <> 'HOLD')  
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)  
      JOIN (   SELECT UCC.UCCNo, UCC.Lot, UCC.Loc, UCC.ID, UCCQty = ISNULL(SUM(UCC.Qty),0)  
               FROM  UCC WITH (NOLOCK)  
               WHERE UCC.Storerkey = @c_Storerkey  
               AND   UCC.[Status] = '1'  
               AND NOT EXISTS (SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK)    
                               WHERE TD.CaseID = UCC.UCCNo AND TD.Status < '9'   
                               )  
               GROUP BY UCC.UCCNo, UCC.Lot, UCC.Loc, UCC.ID  
               HAVING COUNT(DISTINCT UCC.Sku) = 1 AND MIN(UCC.Sku)  = @c_Sku  
            )   CS ON LLI.Lot = CS.Lot AND LLI.Loc = CS.Loc AND LLI.ID = CS.ID  
      WHERE LLI.Storerkey = @c_Storerkey  
      AND   LLI.Sku = @c_Sku  
      AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked >= CS.UCCQty              --(Wan01)
      AND   LOC.Facility = @c_Facility              
      AND   LOC.LocationType = 'OTHER'  
      AND   LOC.LocationCategory = 'BULK'  
      AND   (( @c_LocationHandling = '3' AND LA.Lottable01 IN ( 'A','' ) ) OR  
               ( @c_LocationHandling = '4' AND LA.Lottable01 = 'B' )  
            )  
      ORDER BY LOC.LocationHandling DESC  
               ,LOC.LogicalLocation  
               ,LOC.Loc  
  
      OPEN @CUR_REPLUCC  
  
      FETCH NEXT FROM @CUR_REPLUCC INTO @c_Lot       
                                       ,@c_FromLoc   
                                       ,@c_ID        
                                       ,@c_DropID    
                                       ,@n_UCCQty    
                                       ,@c_LogicalFromLoc  
  
      WHILE @@FETCH_STATUS <> -1 AND @n_RemainingQty > 0  
      BEGIN  
         IF @n_UCCQty > @n_RemainingQty  
         BEGIN  
            SET @n_RemainingQty = 0  
            GOTO NEXT_REPLUCC  
         END  
  
         IF @c_DropID = ''  
         BEGIN  
            SET @n_RemainingQty = 0  
            GOTO NEXT_REPLUCC  
         END  
         ------------------------------------------------------------------------------------  
         -- Create TaskDetail (START)  
         ------------------------------------------------------------------------------------  
         SET @c_TaskDetailkey = ''  
         SET @c_SourceType = 'ispRLWAV52_RPF-REPLEN' --+ RTRIM(@c_DispatchPiecePickMethod) --(Wan14)  
         SET @c_TaskType = 'RPF'  
         SET @c_LogicalToLoc = @c_ToLoc  
         SET @c_ToLocType = 'DPP'  
         SET @c_PickMethod= 'PP'  
         SET @c_UOM = '7'  
         SET @n_Qty = 0  
  
         SET @b_success = 1    
         EXECUTE nspg_getkey    
               'TaskDetailKey'   
               , 10    
               , @c_taskdetailkey OUTPUT    
               , @b_success   OUTPUT    
               , @n_err       OUTPUT    
               , @c_errmsg    OUTPUT  
                   
         IF NOT @b_success = 1    
         BEGIN    
            SET @n_Continue = 3  
            GOTO QUIT_SP    
         END    
   
         SET @c_TransitLoc = ''  
         SET @c_FinalLoc = ''  
         SET @c_FinalID = '' 
          
         IF @c_ToLocType = 'PS' AND @c_TaskType = 'RPF'              
            SET @c_TransitLoc = @c_Toloc  
         ELSE IF @c_ToLocType IN('DP','DPP') AND @c_TaskType = 'RPF'  
         BEGIN  
            SELECT @c_TransitLoc = PICKZONE.InLoc               -- INC1444738 
            FROM LOC (NOLOCK)  
            JOIN PICKZONE (NOLOCK) ON LOC.Pickzone = PICKZONE.Pickzone  
            WHERE LOC.Loc = @c_Toloc 
         
            
            IF @c_TransitLoc IS NULL  
               SET @c_TransitLoc = ''
              
            SET @c_FinalLoc = @c_LogicalToLoc  
            SET @c_FinalID = @c_ID                                               
         END         
  
         INSERT TASKDETAIL    
            (    
               TaskDetailKey    
            ,  TaskType    
            ,  Storerkey    
            ,  Sku    
            ,  UOM    
            ,  UOMQty    
            ,  Qty    
            ,  SystemQty  
            ,  Lot    
            ,  FromLoc    
            ,  FromID    
            ,  ToLoc    
            ,  ToID    
            ,  SourceType    
            ,  SourceKey    
            ,  [Priority]    
            ,  SourcePriority    
            ,  [Status]    
            ,  LogicalFromLoc    
            ,  LogicalToLoc    
            ,  PickMethod  
            ,  Wavekey  
            ,  Message02   
            ,  Areakey  
            ,  Message03  
            ,  Caseid  
            ,  Loadkey  
            ,  PendingMoveIn                                                       
            ,  TransitLoc                        
            ,  FinalLoc 
            ,  FinalID                           
            )    
            VALUES    
            (    
               @c_taskdetailkey    
            ,  @c_TaskType       --Tasktype    
            ,  @c_Storerkey       
            ,  @c_Sku            
            ,  @c_UOM            -- UOM,    
            ,  @n_UCCQty         -- UOMQty,    
            ,  @n_UCCQty         --Qty  
            ,  @n_Qty            --systemqty  
            ,  @c_Lot     
            ,  @c_Fromloc     
            ,  @c_ID             -- from id    
            ,  @c_Toloc          
            ,  @c_ID             -- to id    
            ,  @c_SourceType     --Sourcetype    
            ,  @c_Wavekey        --Sourcekey    
            ,  '5'               -- Priority    
            ,  '9'               -- Sourcepriority    
            ,  '0'               -- Status    
            ,  @c_LogicalFromLoc --Logical from loc    
            ,  @c_LogicalToLoc   --Logical to loc    
            ,  @c_PickMethod  
            ,  @c_Wavekey  
            ,  @c_ToLocType  
            ,  ''  
            ,  ''  
            ,  @c_DropID  
            ,  ''  
            ,  @n_UCCQty       
            ,  @c_TransitLoc  
            ,  @c_FinalLoc  
            ,  @c_FinalID              
            )  
      
         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_Err = 81130   
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV52_RPF)'   
            GOTO QUIT_SP  
         END     
  
         ------------------------------------------------------------------------------------  
         -- Create TaskDetail (END)  
         ------------------------------------------------------------------------------------  
         SET @n_RemainingQty = @n_RemainingQty - @n_UCCQty  
  
         NEXT_REPLUCC:  
         FETCH NEXT FROM @CUR_REPLUCC INTO @c_Lot       
                                          ,  @c_FromLoc   
                                          ,  @c_ID        
                                          ,  @c_DropID    
                                          ,  @n_UCCQty    
                                          ,  @c_LogicalFromLoc  
      END  
      CLOSE @CUR_REPLUCC  
      DEALLOCATE @CUR_REPLUCC  
  
      FETCH NEXT FROM @CUR_SxL INTO @c_Storerkey  
                                 ,  @c_Sku  
                                 ,  @c_ToLoc  
                                 ,  @n_Severity  
                                 ,  @c_LocationHandling  
   END  
   CLOSE @CUR_SxL  
   DEALLOCATE @CUR_SxL  
   ------------------------------------------------------------------------------------  
   -- Replenishment - END  
   ------------------------------------------------------------------------------------  
          
                 
   DECLARE @CUR_DP CURSOR           
   SET @CUR_DP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
   SELECT LDP.PickZone          
         ,LDP.LogicalLocStart              
   FROM @t_DPRange  LDP                
   ORDER BY LDP.PickZone           
                   
   OPEN @CUR_DP                
   FETCH NEXT FROM @CUR_DP INTO  @c_DPPPKZone               
                              ,  @c_logicalloc              
           
   WHILE @@FETCH_STATUS <> -1                
   BEGIN              
      IF EXISTS ( SELECT 1          
                  FROM CODELKUP CL WITH (NOLOCK)          
                  WHERE CL.ListName = 'NKPHLDPLoc'          
                  AND   CL.Code = @c_DPPPKZone          
                  AND   CL.Storerkey = @c_Storerkey          
                )          
      BEGIN          
         UPDATE CODELKUP          
         SET UDF01 = @c_LogicalLoc          
         WHERE ListName = 'NKPHLDPLoc'          
         AND Code = @c_DPPPKZone          
         AND Storerkey = @c_Storerkey          
         AND Code2 = ''          
      END           
      ELSE          
      BEGIN          
         INSERT INTO CODELKUP (ListName, Code, Description, Storerkey, UDF01)          
         VALUES ('NKPHLDPLoc', @c_DPPPKZone,  @c_DPPPKZone, @c_Storerkey, @c_LogicalLoc)          
      END          
          
      IF @@ERROR <> 0          
      BEGIN          
         SET @n_continue = 3                
         SET @n_err = 81140                  
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)          
                      +': Insert/Update Last DP Location into CODELKUP Table for ListName = ''NKPHLDPLoc'' Failed. (ispRLWAV52_RPF)'                 
         GOTO QUIT_SP           
      END           
                                                     
      FETCH NEXT FROM @CUR_DP INTO @c_DPPPKZone               
                                 , @c_logicalloc           
   END          
   CLOSE @CUR_DP          
   DEALLOCATE @CUR_DP               
         
QUIT_SP:  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_PD  
      DEALLOCATE CUR_PD  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ID') in (0 , 1)    
   BEGIN  
      CLOSE CUR_ID  
      DEALLOCATE CUR_ID  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_UPD') in (0 , 1)    
   BEGIN  
      CLOSE CUR_UPD  
      DEALLOCATE CUR_UPD  
   END  
     
   IF OBJECT_ID('tempdb..#TMP_PICK','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_PICK;  
   END  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_DPP') in (0 , 1)    
   BEGIN  
      CLOSE CUR_DPP  
      DEALLOCATE CUR_DPP  
   END  
  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV52_RPF'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
   BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure 

GO