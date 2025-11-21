SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/      
/* Stored Procedure: ispRLWAV38                                          */      
/* Creation Date: 2020-12-31                                             */      
/* Copyright: LFL                                                        */      
/* Written by: Wan                                                       */      
/*                                                                       */      
/* Purpose: WMS-15653 - HK - Lululemon Relocation Project-Release Wave CR*/      
/*        : Copy and develop from ispRLWAV04                             */      
/* Called By: wave                                                       */      
/*                                                                       */      
/* PVCS Version: 1.1                                                     */      
/*                                                                       */      
/* Version: 7.0                                                          */      
/*                                                                       */      
/* Data Modifications:                                                   */      
/*                                                                       */      
/* Updates:                                                              */      
/* Date        Author   Ver   Purposes                                   */  
/* 2020-12-31  Wan      1.0   Created                                    */
/* 2021-07-19  Wan01    1.1   Fixed.RPF UPdate Taskdetailkey to wrong sku*/
/* 2021-08-09  Wan02    1.1   Fixed.Generate RPF for empty string or NULL*/
/*                            pickdetail.taskdetailkey                   */
/* 2021-01-12  NJOW01   1.2   WMS-18717 Remove PK and SPK task if wave   */
/*                            userdefine01 = ''. Create transmitlog      */
/* 2021-01-12  NJOW01   1.2   DEVOPS combine script                      */
/* 2023-10-09  Michael  1.3   New DC code (ML01)                         */
/* 2023-10-13  Michael  1.4   WMS-23889 move hardcoded DC Code to        */
/*                            CodeLkup LULUDCCODE with UDF01=4PL (ML02)  */
/*************************************************************************/       
CREATE   PROCEDURE [dbo].[ispRLWAV38]          
                 @c_wavekey      NVARCHAR(10)      
                ,@b_Success      int        OUTPUT      
                ,@n_err          int        OUTPUT      
                ,@c_errmsg       NVARCHAR(250)  OUTPUT      
AS      
BEGIN      
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF       
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @n_continue  INT = 1        
         , @n_starttcnt INT = @@TRANCOUNT    -- Holds the current transaction count      
         , @n_debug     INT = 0    
         , @n_cnt       INT = 0 
         
         , @n_MixPickMezzAndBulk INT = 0    

         , @b_PTL                  INT          = 0           --v1.6 2021-03-26
         , @b_CallWCS_SP           INT          = 0           --v1.6 2021-03-26
         , @c_PTLStationLogQueue   NVARCHAR(30) = ''          --v1.6 2021-03-26                
   
   DECLARE @c_OrderType             NVARCHAR(10)   = ''     
         , @c_Orderkey              NVARCHAR(10)   = '' 
         , @c_Storerkey             NVARCHAR(15)   = '' 
         , @c_Consigneekey          NVARCHAR(15)   = '' 
         , @c_Sku                   NVARCHAR(20)   = '' 
         , @c_Lot                   NVARCHAR(10)   = '' 
         , @c_FromLoc               NVARCHAR(10)   = '' 
         , @c_ID                    NVARCHAR(18)   = '' 
         , @n_Qty                   INT            = 0
         , @n_UOMQty                INT            = 0
         , @c_Areakey               NVARCHAR(10)   = '' 
         , @c_Facility              NVARCHAR(5)    = ''
         , @c_Packkey               NVARCHAR(10)   = '' 
         , @c_UOM                   NVARCHAR(10)   = ''    
         , @c_Pickslipno            NVARCHAR(10)   = '' 
         , @c_Loadkey               NVARCHAR(10)   = '' 
         , @c_PickZone              NVARCHAR(10)   = ''     
         , @n_Pickqty               INT            = 0
         , @n_ReplenQty             INT            = 0
         , @c_Pickdetailkey         NVARCHAR(18)   = '' 
         , @c_Taskdetailkey         NVARCHAR(10)   = ''  
         , @c_TaskType              NVARCHAR(10)   = ''  
         , @c_PickMethod            NVARCHAR(10)   = '' 
         , @c_Toloc                 NVARCHAR(10)   = '' 
         , @c_SourceType            NVARCHAR(30)   = '' 
         , @c_Message03             NVARCHAR(20)   = '' 
         , @c_LogicalFromLoc        NVARCHAR(18)   = '' 
         , @c_LogicalToLoc          NVARCHAR(18)   = ''          
         , @c_Priority              NVARCHAR(10)   = ''    
         , @c_ListName              NVARCHAR(10)   = '' 
         , @c_TableColumnName       NVARCHAR(250)  = ''
         , @c_SQLGroup              NVARCHAR(2000) = ''  
         , @c_SQL                   NVARCHAR(4000) = '' 
         , @n_Found                 INT            = 0
         , @c_curPickdetailkey      NVARCHAR(10)   = ''
         , @c_TaskStatus            NVARCHAR(10)   = ''                    
         , @n_TaskShort             INT            = 0  
         , @c_FinalLoc              NVARCHAR(10)   = ''     --v1.8 2021-04-30
         
   DECLARE 
           @c_Userdefine01          NVARCHAR(20)   = ''                    
         , @c_ReplenishmentKey      NVARCHAR(10)   = ''                    
         , @c_ToID                  NVARCHAR(18)   = ''                    
         , @c_DropID                NVARCHAR(20)   = ''                    
         , @c_OLDID                 NVARCHAR(20)   = ''                    
         , @n_ReplenSeq             INT            = 0                   
         , @n_zonecnt1              INT            = 0                   
         , @n_zonecnt2              INT            = 0                    
         , @c_authority             NVARCHAR(30)   = ''                    
         , @c_option1               NVARCHAR(50)   = ''                    

   DECLARE @c_LoadPlanGroup         NVARCHAR(30)   = '' 
         , @c_UCCNo                 NVARCHAR(20)   = '' 
         , @c_PickType              NVARCHAR(5)    = ''

         , @n_QtyReplen             INT            = 0
         
         , @CUR_PICK                CURSOR  
         , @CUR_PICK_E              CURSOR
         , @CUR_PICK_R              CURSOR
         , @CUR_PICK_RPL            CURSOR
         , @CUR_PSLP                CURSOR
         
   --v1.6 2021-03-06
   DECLARE @t_PLTStation TABLE
   (  RowRef      INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY
   ,  Wavekey     NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  Orderkey    NVARCHAR(10)   NOT NULL DEFAULT('') 
   ,  Loc         NVARCHAR(10)   NOT NULL DEFAULT('')    
   )

   SET @b_success    =  1
   SET @n_err        =  0
   SET @c_errmsg     =  ''                  
   SET @c_Areakey    =  ''    
   SET @c_Orderkey   =  ''                  
   SET @c_Priority   =  '9'                     
    
   --WHILE @@TRANCOUNT > 0     
   --BEGIN      
   --   COMMIT TRAN      
   --END 
   BEGIN TRAN    

   -----Determine order type ECOM Or Retail-----    
   
   SELECT TOP 1 @c_Storerkey = OH.Storerkey  
               ,@c_OrderType = CASE WHEN OH.Type = 'LULUECOM' THEN 'ECOM' ELSE 'RETAIL' END    
               ,@c_Facility  = OH.Facility    
               ,@c_Userdefine01 = W.Userdefine01
   FROM WAVE W WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (W.Wavekey = WD.Wavekey)
   JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)    
   WHERE W.Wavekey = @c_Wavekey     
       
   IF ISNULL(@c_wavekey,'') = ''      
   BEGIN      
      SET @n_continue = 3      
      SET @n_err = 81010      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV38)'     
      GOTO RETURN_SP     
   END      
   
   IF ISNULL(@c_Userdefine01,'') <> ''
   BEGIN
      --NJOW01 Removed
      /*
      SELECT @n_zonecnt1 = COUNT(DISTINCT colvalue) FROM dbo.fnc_DelimSplit(',', @c_Userdefine01) WHERE ISNULL(colvalue,'') <> ''        
        
      SELECT @n_zonecnt2 = COUNT(DISTINCT Putawayzone)  
      FROM PUTAWAYZONE (NOLOCK)
      WHERE Putawayzone IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))
         
      IF ISNULL(@n_zonecnt1,0) <> ISNULL(@n_zonecnt2,0) 
      BEGIN
         SET @n_continue = 3      
         SET @n_err = 81020      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Putawayzone Parameters Passed at userdefine01 (ispRLWAV38)'     
         GOTO RETURN_SP     
      END 
      */
         
      IF EXISTS(  SELECT 1 
                  FROM REPLENISHMENT (NOLOCK) 
                  WHERE Wavekey = @c_Wavekey
                  AND OriginalFromLoc = 'ispRLWAV38')
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 81030     
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released for Paper based replenishment. (ispRLWAV38)'      
         GOTO RETURN_SP         
      END               
   END
    
   -----Wave Validation----- 
   IF EXISTS ( SELECT 1         
               FROM WAVEDETAIL WD WITH (NOLOCK)        
               JOIN ORDERS O WITH (NOLOCK) ON WD.Orderkey = O.Orderkey        
               WHERE O.Status > '5'        
               AND WD.Wavekey = @c_Wavekey)        
   BEGIN        
      SET @n_continue = 3          
      SET @n_err = 81040          
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV38)'               
      GOTO RETURN_SP        
   END                   
    
   IF EXISTS ( SELECT 1    
               FROM WAVEDETAIL WD WITH (NOLOCK)    
               JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)    
               WHERE WD.Wavekey = @c_Wavekey     
               GROUP BY WD.Wavekey    
               HAVING COUNT( DISTINCT CASE WHEN OH.Type = 'LULUECOM'  THEN 'ECOM' ELSE 'RETAIL' END ) > 1)    
   BEGIN    
      SET @n_continue = 3      
      SET @n_err = 81050     
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Mix order type in this Wave (ispRLWAV38)'           
      GOTO RETURN_SP    
   END 
   
   ;WITH ORD_ECOM ( Orderkey, NoOfPickType, PickFromType )
    AS ( SELECT OH.Orderkey
              , NoOfPickType = COUNT(DISTINCT CASE WHEN DropID = '' THEN 'Loose' ELSE 'Bulk' END) 
              , PickFromType = MIN(CASE WHEN DropID = '' THEN 'Loose' ELSE 'Bulk' END)
               FROM WAVEDETAIL WD WITH (NOLOCK)    
               JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey  
               JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey                 
               WHERE WD.Wavekey = @c_Wavekey 
               AND OH.Type = 'LULUECOM'    
               GROUP BY WD.Wavekey, OH.Orderkey  
    )
     
   SELECT @n_MixPickMezzAndBulk = 1
   FROM ORD_ECOM
   HAVING COUNT( DISTINCT
                  CASE WHEN NoOfPickType > 1 THEN 'MIX'
                  WHEN NoOfPickType = 1 AND PickFromType = 'Loose' THEN 'Loose'
                  WHEN NoOfPickType = 1 AND PickFromType = 'Bulk'  THEN 'BULK' 
                  END
                  ) > 1
                            
   IF @n_MixPickMezzAndBulk > 1 
   BEGIN    
      SET @n_continue = 3      
      SET @n_err = 81060      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed.'
                   +'Found Wave Orders To Pick from Mezzanine & Bulk location And Only Mezzanine'
                   +'. (ispRLWAV38)'           
      GOTO RETURN_SP    
   END    
   
   
   Execute nspGetRight                                
      @c_Facility  = @c_facility,                     
      @c_StorerKey = @c_StorerKey,                    
      @c_sku       = '',                          
      @c_ConfigKey = 'ReleaseWave_SP', -- Configkey         
      @b_Success   = @b_success   OUTPUT,             
      @c_authority = @c_authority OUTPUT,             
      @n_err       = @n_err       OUTPUT,             
      @c_errmsg    = @c_errmsg    OUTPUT,             
      @c_Option1   = @c_option1   OUTPUT           
       
   -- Check unique loadplan group  
   IF EXISTS ( SELECT 1
               FROM CODELIST CLS WITH (NOLOCK) 
               WHERE CLS.Listname = @c_LoadPlanGroup
               AND CLS.ListGroup = 'WAVELPGROUP' 
               )
   BEGIN
      SET @c_SQLGroup = RTRIM(ISNULL(CONVERT(NVARCHAR(4000),   
                  (  SELECT ISNULL(RTRIM(CL.Long),'') + ', '  
                     FROM CODELKUP CL WITH (NOLOCK) 
                     WHERE CL.Listname = @c_LoadPlanGroup
                     AND CL.Long <> '' AND CL.Long IS NOT NULL 
                     ORDER BY CL.Code 
                     FOR XML PATH(''), TYPE   
                  )  
                  ),''))    
  
      IF RIGHT(@c_SQLGroup,2) = ', '  
      BEGIN  
         SET @c_SQLGroup = SUBSTRING(@c_SQLGroup,1 ,LEN(@c_SQLGroup) - 1)  
      END  
  
      IF LEN(@c_SQLGroup) > 0  
      BEGIN  
         SET @n_Found = 0  
         SET @c_SQL = ' SELECT @n_Found = 1'    
                    + ' FROM  WAVEDETAIL WITH (NOLOCK)'    
                    + ' JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)'   
                    + ' WHERE WAVEDETAIL.Wavekey = @c_Wavekey'   
                    + ' GROUP BY ' + @c_SQLGroup   
                    + ' HAVING COUNT(DISTINCT ORDERS.Loadkey) > 1'    
  
            
         EXEC sp_executesql @c_SQL     
                          , N' @c_Wavekey NVARCHAR(10), @n_Found INT OUTPUT'      
                          , @c_Wavekey                          
                          , @n_Found OUTPUT   
  
         IF @n_Found = 1  
         BEGIN    
            SET @n_continue = 3      
            SET @n_err = 81070     
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Different Loadkey with same Loadplan group Found. (ispRLWAV38)'           
            GOTO RETURN_SP    
         END    
      END  
   END       
  
   -- Create TEMP PICKDETAILKEY TABLE
   IF OBJECT_ID('tempdb..#TMP_PICKDETAIL','u') IS NOT NULL
   BEGIN
      DROP TABLE TMP_PICKDETAIL;
   END
   
   CREATE TABLE #TMP_PICKDETAIL 
      (  
         PickdetailKey     NVARCHAR(10) NOT NULL Primary KEY
      ,  WaveKey           NVARCHAR(10) NOT NULL DEFAULT('')  
      ,  Loadkey           NVARCHAR(10) NOT NULL DEFAULT('')          
      ,  OrderKey          NVARCHAR(10) NOT NULL DEFAULT('') 
      ,  PackKey           NVARCHAR(10) NOT NULL DEFAULT('')       
      ,  PackUOM3          NVARCHAR(10) NOT NULL DEFAULT('') 
      ,  PutawayZone       NVARCHAR(10) NOT NULL DEFAULT('') 
      ,  WAVEPAZone        INT          NOT NULL DEFAULT(0)
      ,  OrderMode         NVARCHAR(10) NOT NULL DEFAULT('') 
      ,  UCCNo             NVARCHAR(20) NOT NULL DEFAULT('')
      ,  UCCMultiSku       INT          NOT NULL DEFAULT(0)
      ,  UCCQty            INT          NOT NULL DEFAULT(0)       --CR V1.5
      )                                                   
   
   INSERT INTO #TMP_PICKDETAIL
   (
         PickdetailKey   
      ,  WaveKey
      ,  LoadKey                   
      ,  OrderKey
      ,  PackKey          
      ,  PackUOM3          
      ,  PutawayZone       
      ,  WAVEPAZone  
      ,  UCCNo      
      )      
   SELECT PD.Pickdetailkey 
         ,WD.Wavekey 
         ,ISNULL(LPD.Loadkey,'')      
         ,PD.Orderkey
         ,SKU.PackKey
         ,P.PackUOM3
         ,L.PutawayZone
         ,WAVEPAZone = CASE WHEN (SELECT TOP 1 1 FROM string_split (@c_Userdefine01, ',') WHERE [VALUE] = L.PutawayZone) = 1 THEN 1 ELSE 0 END  
         ,PD.DropID        
   FROM WAVEDETAIL WD WITH (NOLOCK) 
   JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey       
   JOIN SKU    SKU WITH (NOLOCK) ON SKU.StorerKey = PD.Storerkey AND SKU.Sku = PD.Sku  
   JOIN PACK   P   WITH (NOLOCK) ON SKU.PackKey = P.Packkey     
   JOIN LOC    L   WITH (NOLOCK) ON PD.Loc = L.Loc 
   LEFT JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.Orderkey = WD.Orderkey  
   WHERE WD.Wavekey = @c_Wavekey 
   
   IF NOT EXISTS ( SELECT 1 FROM #TMP_PICKDETAIL p )
   BEGIN
      GOTO RETURN_SP
   END

   ;WITH UCCUPD ( UCCNo, UCCMultiSku, Qty )
    AS(  --CR 1.5
         SELECT UCC.UCCNo
             ,  UCCMultiSku = CASE WHEN COUNT(DISTINCT UCC.Sku) > 1 THEN 1 ELSE 0 END 
             ,  Qty = SUM(UCC.Qty)
         FROM UCC WITH (NOLOCK)
         WHERE UCC.Storerkey = @c_Storerkey
         AND EXISTS ( SELECT 1
                        FROM #TMP_PICKDETAIL TP
                        JOIN PICKDETAIL AS PD WITH (NOLOCK) ON TP.PickdetailKey = PD.PickDetailKey
                        WHERE PD.Storerkey = UCC.Storerkey 
                        AND PD.DropID = UCC.UCCNo
                     )
         GROUP BY UCC.UCCNo
      )   
         
   UPDATE TP
   SET
      UCCMultiSku = UPD.UCCMultiSku
   ,  UCCQty = UPD.Qty                    --CR 1.5
   FROM #TMP_PICKDETAIL TP
   JOIN UCCUPD UPD ON TP.UCCNo = UPD.UCCNo

   --------------------------------------------------
   --Generate PickSlipno - START
   --------------------------------------------------   
   IF @n_continue = 1 or @n_continue = 2      
   BEGIN    
      SET @CUR_PSLP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT DISTINCT     
            OrderKey = TP.Orderkey 
         ,  LoadKey  = TP.LoadKey 
      FROM #TMP_PICKDETAIL TP 

      OPEN @CUR_PSLP      
    
      FETCH NEXT FROM @CUR_PSLP INTO @c_Orderkey, @c_LoadKey           
    
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)     
      BEGIN      
         SET @c_PickZone = '8'         --CASE WHEN @c_OrderKey = '' THEN 'LP' ELSE '8' END    
    
         SET @c_PickSlipno = ''          
         SELECT @c_PickSlipno = PickheaderKey      
         FROM   PICKHEADER (NOLOCK)      
         WHERE  Wavekey  = @c_Wavekey    
         AND    OrderKey = @c_OrderKey    
         AND    Loadkey  = @c_LoadKey    
         AND    [Zone]   = @c_PickZone               
         
         IF ISNULL(@c_PickSlipno, '') = '' AND ISNULL(@c_Orderkey,'') <> ''
         BEGIN
            SELECT @c_PickSlipno = PickheaderKey      
            FROM   PICKHEADER (NOLOCK)      
            WHERE  OrderKey = @c_OrderKey    
         END   
    
         -- Create Pickheader          
         IF ISNULL(@c_PickSlipno, '') = ''      
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
                     ,  [Zone]    
                     ,  TrafficCop    
                     )      
            VALUES      
                     (  @c_Pickslipno    
                     ,  @c_Wavekey    
                     ,  @c_OrderKey    
                     ,  @c_Loadkey    
                     ,  @c_Loadkey    
                     ,  '0'     
                     ,  @c_PickZone    
                     ,  ''    
                     )          
    
            SET @n_err = @@ERROR      
            IF @n_err <> 0      
            BEGIN      
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81080  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
            END      
         END  

           -- tlting01
         SET @c_curPickdetailkey = ''

         SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PD.Pickdetailkey          
         FROM #TMP_PICKDETAIL TP WITH (NOLOCK)
         JOIN PICKDETAIL      PD WITH (NOLOCK)  ON TP.PickdetailKey = PD.PickDetailKey    
         WHERE TP.OrderKey = @c_OrderKey  
          
         OPEN @CUR_PICK 
         FETCH NEXT FROM @CUR_PICK INTO @c_curPickdetailkey 
         WHILE @@FETCH_STATUS = 0 AND (@n_continue = 1 or @n_continue = 2)
         BEGIN 
            UPDATE PICKDETAIL WITH (ROWLOCK)      
            SET  PickSlipNo = @c_PickSlipNo     
                  ,EditWho = SUSER_SNAME()    
                  ,EditDate= GETDATE()     
                  ,TrafficCop = NULL     
            WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey 
            SET @n_err = @@ERROR    
            IF @n_err <> 0     
            BEGIN    
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81090 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
            END         
            FETCH NEXT FROM @CUR_PICK INTO @c_curPickdetailkey
         END
         CLOSE @CUR_PICK 
         DEALLOCATE @CUR_PICK             
    
         IF NOT EXISTS (SELECT 1 FROM PICKINGINFO WITH (NOLOCK)       
                        WHERE PickSlipNo = @c_PickSlipNo)    
         BEGIN    
            INSERT INTO PICKINGINFO (PickSlipNo, ScanIndate, PickerID)    
            VALUES (@c_PickSlipNo, GETDATE(), SUSER_SNAME())    
    
            SET @n_err = @@ERROR      
            IF @n_err <> 0      
            BEGIN   
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81100 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO Failed (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
            END  
         END    
    
         FETCH NEXT FROM @CUR_PSLP INTO @c_Orderkey, @c_LoadKey           
      END       
      CLOSE @CUR_PSLP      
      DEALLOCATE @CUR_PSLP     
   END    
   --------------------------------------------------
   --Generate PickSlipno - END
   --------------------------------------------------

   --------------------------------------------------
   --v1.6 2021-03-06
   --Call Release PTL - START
   --------------------------------------------------
   SET @b_CallWCS_SP = 0
   SET @b_PTL = 0
   SELECT TOP 1 @b_PTL = 1
   FROM dbo.WAVEDETAIL AS w (NOLOCK)
   JOIN dbo.ORDERS AS o (NOLOCK) ON w.OrderKey = o.OrderKey 
   JOIN dbo.PICKDETAIL AS p (NOLOCK) ON o.OrderKey = p.OrderKey
   WHERE w.WaveKey = @c_Wavekey
   AND o.[Type] <> 'LULUECOM'
--(ML01)   AND o.UserDefine10 NOT IN ('170146','170149')
--(ML02)   AND o.UserDefine10 NOT IN ('170146','170149','170160','170176')  --(ML01)
   AND NOT EXISTS(SELECT TOP 1 1 FROM CODELKUP CL(NOLOCK) WHERE CL.LISTNAME='LULUDCCODE' AND CL.UDF01='4PL' AND CL.Storerkey=o.Storerkey AND CL.Code=o.UserDefine10)   --(ML02)
   AND ISNULL(@c_Userdefine01,'') = ''  --NJOW01

   IF @b_PTL = 1
   BEGIN      
      SELECT @c_PTLStationLogQueue = ISNULL(sc.SValue,'0')
      FROM RDT.StorerConfig AS sc WITH (NOLOCK) 
      WHERE sc.Function_ID = 805
      AND sc.Storerkey = @c_StorerKey
      AND sc.Configkey = 'PTLStationLogQueue'
   
      SET @b_CallWCS_SP = 1
      IF @c_PTLStationLogQueue = '1'
      BEGIN
         SELECT TOP 1 @b_CallWCS_SP = 0
         FROM rdt.rdtPTLStationLogQueue p (NOLOCK)
         WHERE p.WaveKey = @c_wavekey
         AND   p.Storerkey = @c_Storerkey
      END
      ELSE
      BEGIN
         SELECT TOP 1 @b_CallWCS_SP = 0
         FROM rdt.rdtptlstationlog p (NOLOCK)
         WHERE p.WaveKey = @c_wavekey  
         AND   p.Storerkey = @c_Storerkey
      END
   END
   
   IF @b_CallWCS_SP = 1 
   BEGIN
      EXEC [dbo].[isp_WaveReleaseToWCS_Wrapper]    
               @c_WaveKey  =@c_WaveKey
            ,  @b_Success  =@b_Success OUTPUT  
            ,  @n_Err      =@n_Err     OUTPUT   
            ,  @c_ErrMsg   =@c_ErrMsg  OUTPUT    
                
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
         GOTO RETURN_SP
      END      
   END
  
   IF @b_PTL = 1
   BEGIN  
      IF @c_PTLStationLogQueue = '1'
      BEGIN 
         INSERT INTO @t_PLTStation (Wavekey, Orderkey, Loc)
         SELECT p.Wavekey, p.Orderkey, p.Loc
         FROM rdt.rdtPTLStationLogQueue p (NOLOCK)
         WHERE p.WaveKey = @c_wavekey
         AND   p.Storerkey = @c_Storerkey
      END
      ELSE
      BEGIN
         INSERT INTO @t_PLTStation (Wavekey, Orderkey, Loc)
         SELECT p.Wavekey, p.Orderkey, p.Loc
         FROM rdt.rdtptlstationlog p (NOLOCK)
         WHERE p.WaveKey = @c_wavekey
         AND   p.Storerkey = @c_Storerkey       
      END
   END
   --------------------------------------------------
   --v1.6 2021-03-06
   --Call Release PTL - END
   --------------------------------------------------

   --Remove taskdetailkey and add wavekey from pickdetail of the wave        
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      SET @c_curPickdetailkey = ''
      SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PD.Pickdetailkey 
               ,TaskDetailKey = ISNULL(RTRIM(PD.TaskDetailKey),'') 
         FROM #TMP_PICKDETAIL TP
         JOIN PICKDETAIL PD WITH (NOLOCK) ON TP.PickdetailKey = PD.PickDetailKey
         WHERE TP.WAVEPAZone = 0
         AND PD.[Status] = '0'               

      OPEN @CUR_PICK 
      FETCH NEXT FROM @CUR_PICK INTO @c_curPickdetailkey
                                   , @c_TaskDetailKey  
                                            
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2) 
      BEGIN 
         IF @c_TaskDetailKey <> ''
         BEGIN
            SET @n_cnt = 0
            SET @c_TaskStatus = ''
            SET @n_TaskShort  = 0
            SELECT @n_cnt = 1
               ,   @c_TaskStatus = TD.[Status]
               ,   @n_TaskShort  = CASE WHEN TD.SystemQty > TD.Qty THEN 1 ELSE 0 END
            FROM TASKDETAIL TD WITH (NOLOCK)
            WHERE TD.TaskDetailKey = @c_TaskDetailKey

            IF @n_cnt = 0 OR (@c_TaskStatus = '9' AND @n_TaskShort  = 1)
            BEGIN
               SET @c_TaskDetailKey = ''                     -- PickDETAIL.Taskdetailkey not found or TASKDETAIL.Status = '9'
            END 
         END
        
         UPDATE PICKDETAIL WITH (ROWLOCK)     
            SET 
              PICKDETAIL.TaskDetailKey = @c_TaskDetailKey      
            , PICKDETAIL.Wavekey = @c_Wavekey      
            , EditWho    = SUSER_SNAME()    
            , EditDate   = GETDATE()    
            , TrafficCop = NULL     
         WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey 
         
         SET @n_err = @@ERROR    

         IF @n_err <> 0     
         BEGIN    
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 81110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
         END     
         
         NEXT_REC:                                                         
         FETCH NEXT FROM @CUR_PICK INTO @c_curPickdetailkey
                                       , @c_TaskDetailKey        
      END
      CLOSE @CUR_PICK 
      DEALLOCATE @CUR_PICK
   END   
    
   SET @c_TaskDetailKey = ''                                            

   --Remove toloc,dropid,notes pickdetail of the wave for specific zone to replenish by paper based--NJOW02        
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      SET @c_curPickdetailkey = ''
      SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT PD.Pickdetailkey
      FROM #TMP_PICKDETAIL TP
      JOIN PICKDETAIL         PD WITH (NOLOCK) ON TP.PickdetailKey = PD.PickDetailKey
      LEFT JOIN REPLENISHMENT R  WITH (NOLOCK) ON PD.Lot = R.Lot AND PD.Loc = R.FromLoc AND PD.Id = R.ID AND TP.Wavekey = R.Wavekey
      WHERE TP.WAVEPAZone = 1
      AND PD.[Status] = '0' 
      AND PD.Loc <> PD.ToLoc
      AND R.ReplenishmentKey IS NULL 
         
         --FROM WAVEDETAIL WD (NOLOCK)      
         --JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey    
         --JOIN LOC WITH (NOLOCK) ON PD.Loc = LOC.Loc
         --LEFT JOIN REPLENISHMENT R (NOLOCK) ON PD.Lot = R.Lot AND PD.Loc = R.FromLoc AND PD.Id = R.ID AND WD.Wavekey = R.Wavekey --AND PD.Toloc = R.ToLoc
         --WHERE WD.Wavekey = @c_Wavekey            
         --AND PD.Status = '0' 
         --AND PD.Loc <> PD.ToLoc
         --AND R.ReplenishmentKey IS NULL
         --AND LOC.Putawayzone IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))

      OPEN @CUR_PICK 
      FETCH NEXT FROM @CUR_PICK INTO @c_curPickdetailkey

      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)
      BEGIN         
        UPDATE PICKDETAIL WITH (ROWLOCK)     
           SET ToLoc      = '',
               DropId     = '',
               Notes      = '',
               EditWho    = SUSER_SNAME(),    
               EditDate   = GETDATE(),    
               TrafficCop = NULL     
        WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey 
           
        SET @n_err = @@ERROR
        
        IF @n_err <> 0     
        BEGIN    
           SET @n_continue = 3      
           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
           SET @n_err = 81120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
        END     
         
        FETCH NEXT FROM @CUR_PICK INTO @c_curPickdetailkey
      END
      CLOSE @CUR_PICK 
      DEALLOCATE @CUR_PICK
   END    
     
   --Create Temporary Tables   
   --IF (@n_continue = 1 OR @n_continue = 2)  AND @c_OrderType = 'ECOM'  
   --BEGIN    
   --   CREATE TABLE  #Orders (  
   --       RowRef    BIGINT IDENTITY(1,1) Primary Key,  
   --       OrderKey  NVARCHAR(10)  
   --      ,SKUCount  INT  
   --      ,TotalPick INT  
   --      )                                                   
   --END   
   
   -----Retail Order Initialization and Validation-----     
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderType = 'RETAIL'    
      AND ISNULL(@c_Userdefine01,'') = '' --NJOW01 
   BEGIN   
    
      -----Generate RETAIL Order Tasks-----    
      SET @CUR_PICK_R = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT  PD.Storerkey     
            , PD.Sku     
            , PD.Lot     
            , PD.Loc     
            , PD.ID     
            , Qty = SUM(PD.Qty)                              
            , PickMethod ='PP'  
            , TP.Packkey    
            , UOM = MIN(PD.UOM) 
            , TP.Loadkey    
            , PD.Orderkey
            , OH.Consigneekey
      FROM #TMP_PICKDETAIL TP
      JOIN PICKDETAIL  PD WITH (NOLOCK) ON TP.PickdetailKey = PD.PickDetailKey
      JOIN ORDERS      OH WITH (NOLOCK) ON TP.Orderkey = OH.Orderkey 
      WHERE TP.WAVEPAZone = 0
      AND TP.PutawayZone NOT IN ('LULUCP')
      AND PD.[Status] = '0'  
      AND PD.DropID   = ''                -- Piece Pick                                       
      AND (PD.TaskDetailKey = '' OR PD.TaskDetailKey IS NULL) 
      GROUP BY PD.Storerkey     
            ,  PD.Sku      
            ,  PD.Lot     
            ,  PD.Loc     
            ,  PD.Id   
            ,  TP.Packkey  
            ,  TP.Loadkey       
            ,  PD.Orderkey
            ,  OH.Consigneekey
      ORDER BY PD.Storerkey, PD.Sku                              
    
      OPEN @CUR_PICK_R      
      FETCH NEXT FROM @CUR_PICK_R INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey, @c_UOM, @c_Loadkey, @c_Orderkey, @c_Consigneekey
    
      -- Create SPK tasks    
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)    
      BEGIN     
         SET @c_Tasktype = 'SPK'
         SET @c_SourceType = 'ispRLWAV38-RETAIL'        
         SET @c_ToLoc        = ''          
         SET @c_LogicalToLoc = ''      
         SET @c_Priority  = '5' 
         SET @c_TaskStatus= 'N'  
         SET @c_UCCNo     = ''                  

         SET @n_UOMQty = 0 

         SET @c_Message03 = @c_Orderkey
         
         --v1.6 2021-03-26
         IF @b_PTL = 1
         BEGIN
            SELECT TOP 1 @c_ToLoc = tps.Loc
            FROM @t_PLTStation AS tps
            JOIN LOC AS l WITH (NOLOCK) ON tps.Loc = l.Loc
            WHERE tps.Wavekey = @c_wavekey
            AND tps.Orderkey = @c_Orderkey
            ORDER BY l.putawayzone
                  ,  l.logicallocation
                  ,  l.loc
         
            IF @c_ToLoc = ''
            BEGIN
               SET @n_continue = 3      
               SET @n_err = 81130      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PLT Loc Not Found. (ispRLWAV38)'           
               GOTO RETURN_SP   
            END
         END  
                   
         GOTO RELEASE_TASKS    
         RETAIL:    
      
         FETCH NEXT FROM @CUR_PICK_R INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey, @c_UOM, @c_Loadkey, @c_Orderkey, @c_Consigneekey
      END    
      CLOSE @CUR_PICK_R    
      DEALLOCATE @CUR_PICK_R    
   END  
    
   -----Generate ECOM Order Tasks-----   
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderType = 'ECOM'    
      AND ISNULL(@c_Userdefine01,'') = '' --NJOW01 
   BEGIN 
      WITH EORDUPD ( Orderkey, OrderMode )
      AS (
            SELECT TP.OrderKey
               ,OrderMode = CASE WHEN COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) = 1 THEN 'SINGLES' ELSE 'MULTIS' END 
            FROM #TMP_PICKDETAIL TP
            JOIN PICKDETAIL PD WITH (NOLOCK) ON TP.Orderkey = PD.Orderkey
            GROUP BY TP.OrderKey
         )   
         
      UPDATE TP
      SET
         OrderMode = UPD.OrderMode
      FROM #TMP_PICKDETAIL TP
      JOIN EORDUPD UPD ON TP.OrderKey = UPD.Orderkey
         
      -- Retrieve SINGLES & MULTI  
      SET @CUR_PICK_E = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT PD.Storerkey     
           , PD.Sku     
           , PD.Lot     
           , PD.Loc     
           , PD.ID     
           , Qty = SUM(PD.Qty)                              
           , PickMethod = TP.OrderMode                                                   --CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN 'SINGLES' ELSE 'MULTIS' END 
           , Orderkey   = CASE WHEN TP.OrderMode = 'SINGLES' THEN '' ELSE PD.Orderkey END--CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN '' ELSE PD.Orderkey END
           , TP.Loadkey
           , ToLoc = ISNULL(CL.Long, '')    
      FROM #TMP_PICKDETAIL TP 
      JOIN ORDERS     OH WITH (NOLOCK) ON TP.Orderkey = OH.Orderkey 
      JOIN PICKDETAIL PD WITH (NOLOCK) ON TP.Pickdetailkey = PD.Pickdetailkey 
      LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK) ON  CL.LISTNAME = 'WCSStation'
                                                AND CL.Code = OH.Userdefine02 
      WHERE TP.WAVEPAZone = 0
      AND TP.PutawayZone NOT IN ('LULUCP')
      AND PD.[Status] = '0'  
      AND PD.DropID   = ''                -- Piece Pick
      AND (PD.TaskDetailKey = '' OR PD.TaskDetailKey IS NULL) 
      GROUP BY CASE WHEN TP.OrderMode = 'SINGLES' THEN '' ELSE PD.Orderkey END
              , PD.Storerkey     
              , PD.Sku     
              , PD.Lot     
              , PD.Loc     
              , PD.ID     
              , TP.OrderMode 
              , TP.Loadkey
              , ISNULL(CL.Long, '')        
      ORDER BY TP.OrderMode
            ,  Orderkey  
            ,  PD.Loc   
            ,  PD.Sku  
                
      OPEN @CUR_PICK_E      
      FETCH NEXT FROM @CUR_PICK_E INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty   
                                     , @c_PickMethod, @c_Orderkey, @c_Loadkey, @c_ToLoc   
    
     
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)     
      BEGIN        
         SET @c_tasktype = 'PK'    
         SET @c_SourceType = 'ispRLWAV38-ECOM'   
         
         SET @c_LogicalToLoc = ''      
         SET @c_UOM = '' 
         SET @c_TaskStatus = 'N'
         SET @c_UCCNo      = ''    
         SET @n_UOMQty = 0 
                  
         IF @c_PickMethod = 'MULTIS'
         BEGIN
            SET @c_Message03 = @c_Orderkey
            SET @c_Priority = '5'
         END
         ELSE
         BEGIN
            SET @c_Message03 = @c_Wavekey
            SET @c_Priority = '4'
         END
            
         GOTO RELEASE_TASKS    
         ECOM:   
         FETCH NEXT FROM @CUR_PICK_E INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty   
                                       ,  @c_PickMethod, @c_Orderkey, @c_Loadkey, @c_ToLoc              
      END --Fetch    
      CLOSE @CUR_PICK_E      
      DEALLOCATE @CUR_PICK_E                                     
   END    

   -- Generate Replenishment Task  for PICKDETAIL.PuTWAYZone Not IN WAVE.Userdefine01
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN
      SET @CUR_PICK_RPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT PD.Storerkey                          --1. Yoga Mat / Piece Loc    
            ,PD.Sku     
            ,Lot = ''    
            ,PD.Loc     
            ,PD.ID     
            ,Qty = SUM(PD.Qty)
            ,PickMethod = 'PP'                              
            ,TP.Packkey    
            ,PD.UOM
            ,DropID = ''
            ,PickType = 'PIECE'   
      FROM #TMP_PICKDETAIL TP 
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TP.Pickdetailkey = PD.Pickdetailkey) 
      WHERE TP.WAVEPAZone = 0
      AND TP.PutawayZone IN ('LULUCP')
      AND PD.[Status] = '0'
      AND PD.UOM = '7' 
      AND PD.DropID = ''
      AND (PD.ToLoc = ''  OR PD.ToLoc IS  NULL) 
      AND (PD.TaskDetailKey = '' OR PD.TaskDetailKey IS NULL)                    --(Wan02) - Fixed  
      GROUP BY PD.Storerkey     
            , PD.Sku      
            , PD.Loc     
            , PD.Id   
            , TP.Packkey   
            , PD.UOM   
      UNION 
      SELECT PD.Storerkey                       --2. BULK Loc    
            ,Sku = CASE WHEN TP.UCCMultiSku = 1 THEN '' ELSE PD.Sku END    
            ,Lot = CASE WHEN TP.UCCMultiSku = 1 THEN '' ELSE PD.Lot END     
            ,PD.Loc     
            ,PD.ID     
            ,TP.UCCQty                                                              --v1.5 CR --SUM(CASE WHEN TP.UCCMultiSku = 1 THEN 0  ELSE PD.Qty END)  
            ,PickMethod = 'PP'                                 
            ,TP.Packkey    
            ,PD.UOM
            ,PD.DropId 
            ,PickType = 'BULK'   
      FROM #TMP_PICKDETAIL TP 
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON TP.Pickdetailkey = PD.Pickdetailkey 
      WHERE TP.WAVEPAZone = 0
      AND PD.[Status] = '0'        
      AND PD.DropId <> '' 
      AND (PD.TaskDetailKey = '' OR PD.TaskDetailKey IS NULL)                    --(Wan02) - Fixed
      GROUP BY PD.Storerkey     
            ,  CASE WHEN TP.UCCMultiSku = 1 THEN '' ELSE PD.Sku END   
            ,  CASE WHEN TP.UCCMultiSku = 1 THEN '' ELSE PD.Lot END     
            ,  PD.Loc     
            ,  PD.Id   
            ,  TP.Packkey   
            ,  PD.UOM 
            ,  PD.DropId 
            ,  TP.UCCQty                                                         --v1.5 CR 
      ORDER BY Storerkey
            , PickType              -- Sort By Piece Then BULK 
            , Sku
            , Loc
            , LoT                            
      
      OPEN @CUR_PICK_RPL      
      FETCH NEXT FROM @CUR_PICK_RPL INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey, @c_UOM, @c_UCCNo, @c_PickType
                        
      -- Create Replenishment Task records
      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)   
      BEGIN
         SET @c_tasktype    = 'RPF'  
         SET @c_SourceType  = 'ispRLWAV38-RPF' 
         SET @c_ToLoc       = 'LULUWS01'                                
         SET @c_LogicalToLoc= ''      
         SET @c_Priority    = '5'
         SET @c_TaskStatus  = 'N'            --2021-06-25 CR2.1
         SET @c_Message03   = ''
         
         SET @c_Orderkey    = ''
         SET @c_Loadkey     = ''
         
         SET @n_UOMQty = @n_Qty

         --v1.8 2021-04-30
         --SET @c_FinalLoc = ''     --v1.9 2021-05-11 Finalloc for Bulk & Piece - START 
         --IF @c_UCCNo <> ''
         --BEGIN
            SET @c_FinalLoc = 'LULUWS01'
         --END                      --v1.9 2021-05-11 Finalloc for Bulk & Piece - END 
                  
         --v1.6 2021-03-26
         IF @b_PTL = 1 AND @c_UCCNo <> ''
         BEGIN
            SET @c_ToLoc = ''
            SELECT TOP 1 @c_ToLoc = tps.Loc
            FROM @t_PLTStation AS tps
            JOIN #TMP_PICKDETAIL AS pd  ON tps.Orderkey = pd.OrderKey
            JOIN LOC AS l WITH (NOLOCK) ON tps.Loc = l.Loc
            WHERE tps.Wavekey = @c_wavekey
            AND pd.UCCNo = @c_UCCNo
            ORDER BY l.putawayzone
                  ,  l.logicallocation
                  ,  l.loc
         
            IF @c_ToLoc = ''
            BEGIN
               SET @n_continue = 3      
               SET @n_err = 81140      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PLT Loc Not Found. (ispRLWAV38)'           
               GOTO RETURN_SP   
            END
         END
         
         GOTO RELEASE_TASKS
         TASKREPL:
         
         FETCH NEXT FROM @CUR_PICK_RPL INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey, @c_UOM, @c_UCCNo, @c_PickType
      END
      CLOSE @CUR_PICK_RPL
      DEALLOCATE @CUR_PICK_RPL      
   END  

   -----Generate replenishment record for specific zone to replenish by paper based. 
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_Userdefine01,'') <> '' 
   BEGIN
      SET @n_ReplenSeq = 0

      SELECT @n_ReplenSeq = ISNULL(COUNT(DISTINCT PD.DropID),0)
      FROM #TMP_PICKDETAIL TP 
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TP.Pickdetailkey = PD.Pickdetailkey) 
      WHERE TP.WAVEPAZone = 1
      AND PD.DropID <> '' 
      AND PD.ToLoc <> ''  AND PD.ToLoc IS NOT NULL
              
      SELECT @c_ToLoc = Code  
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'LUREPLEN' 
      
      SET @CUR_PICK_RPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT PD.Storerkey     
           , PD.Sku     
           , PD.Lot     
           , PD.Loc     
           , PD.ID     
           , SUM(PD.Qty)                              
           , TP.Packkey    
           , TP.PackUOM3  
      FROM #TMP_PICKDETAIL TP 
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TP.Pickdetailkey = PD.Pickdetailkey) 
      WHERE TP.WAVEPAZone = 1
      AND PD.[Status] = '0' 
      AND PD.DropID = ''
      AND (PD.ToLoc = '' OR PD.ToLoc IS NULL)       
      GROUP BY PD.Storerkey     
             , PD.Sku      
             , PD.Lot     
             , PD.Loc     
             , PD.Id   
             , TP.Packkey   
             , TP.PackUOM3   
      ORDER BY PD.Storerkey, PD.Sku, PD.Loc, PD.Lot                              
      
      OPEN @CUR_PICK_RPL      
      FETCH NEXT FROM @CUR_PICK_RPL INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Packkey, @c_UOM
                        
      -- Create Replenishment records
      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)   
      BEGIN                 
         SET @n_ReplenSeq = @n_ReplenSeq + 1

         EXECUTE nspg_getkey
            'REPLENISHKEY'
            , 10
            , @c_ReplenishmentKey OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
            
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
          
         IF @c_Option1 = 'ORIGINALID'
         BEGIN
            SET @c_ToId = @c_ID
         END     
         ELSE
         BEGIN             
            SET @c_OldID = ''         
            IF SUBSTRING(@c_ID, 8,1) = '*'  --The ID was converted before.
            BEGIN
               SELECT TOP 1 @c_OldID = PalletFlag
               FROM ID (NOLOCK)
               WHERE ID = @c_ID
            END
            
            IF ISNULL(@c_OldId,'') <> ''
               SET @c_ToID = SUBSTRING(@c_ReplenishmentKey,4,7) + '*' + SUBSTRING(@C_OldID,1,10)
            ELSE
               SET @c_ToID = SUBSTRING(@c_ReplenishmentKey,4,7) + '*' + SUBSTRING(@C_ID,1,10)            
         END
                  
         SET @c_DropID = @c_Wavekey + '-V' + RIGHT('0000' + RTRIM(LTRIM(CAST(@n_ReplenSeq AS NVARCHAR))),4)

         SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT PD.Pickdetailkey, PD.Qty 
            --FROM PICKDETAIL PD (NOLOCK)
            --JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey
            --WHERE WD.Wavekey = @c_Wavekey
            FROM #TMP_PICKDETAIL TP 
            JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TP.Pickdetailkey = PD.Pickdetailkey) 
            WHERE PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
            AND PD.Lot = @c_Lot
            AND PD.Loc = @c_FromLoc
            AND PD.Id  = @c_ID
            AND PD.Status = '0'
            ORDER BY PD.Pickdetailkey
            
         OPEN @CUR_PICK      
         
         FETCH NEXT FROM @CUR_PICK INTO @c_Pickdetailkey, @n_PickQty
                       
         WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)               
         BEGIN   
            IF @c_Option1 = 'ORIGINALID' 
            BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET Qty = @n_PickQty,
                     ToLoc = @c_ToLoc,
                     DropId = @c_DropID,
                     Notes  = @c_DropID
               WHERE Pickdetailkey = @c_Pickdetailkey
                 
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81150  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail Table. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                
               END                                                   
            END
            ELSE
            BEGIN                                  
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET Qty = 0
               WHERE Pickdetailkey = @c_Pickdetailkey
                 
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81160  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail Table. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                
               END                                                  
                                             
               EXEC nspItrnAddMove
                  @n_ItrnSysId = null,
                  @c_StorerKey = @c_Storerkey,
                  @c_Sku = @c_Sku,
                  @c_Lot = @c_Lot,
                  @c_FromLoc = @c_FromLoc,
                  @c_FromID = @c_ID,
                  @c_ToLoc = @c_FromLoc,
                  @c_ToID = @c_ToID,
                  @c_Status = 'OK',
                  @c_lottable01 = '',
                  @c_lottable02 = '',
                  @c_lottable03 = '',
                  @d_lottable04 = null,
                  @d_lottable05 = null,
                  @c_lottable06 = '',
                  @c_lottable07 = '',
                  @c_lottable08 = '',
                  @c_lottable09 = '',
                  @c_lottable10 = '',
                  @c_lottable11 = '',
                  @c_lottable12 = '',
                  @d_lottable13 = null,
                  @d_lottable14 = null,
                  @d_lottable15 = null,
                  @n_casecnt = 0,
                  @n_innerpack = 0,
                  @n_qty = @n_PickQty,
                  @n_pallet = 0,
                  @f_cube = 0,
                  @f_grosswgt = 0,
                  @f_netwgt = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey = null,
                  @c_SourceType = 'ispRLWAV38',
                  @c_PackKey = @c_Packkey,
                  @c_UOM = @c_UOM,
                  @b_UOMCalc = null,
                  @d_EffectiveDate = null,
                  @c_itrnkey = null,
                  @b_Success = @b_Success OUTPUT,
                  @n_err = @n_err OUTPUT,
                  @c_errmsg = @c_errmsg OUTPUT,
                  @c_MoveRefKey = null
                  --@c_Channel = null,
                  --@n_Channel_ID = null
                   
               IF @b_success <> 1
                  SET @n_continue = 3
                    
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET   Qty = @n_PickQty,
                     ID = @c_ToID,
                     ToLoc = @c_ToLoc,
                     DropId = @c_DropID,
                     Notes = @c_DropID
               WHERE Pickdetailkey = @c_Pickdetailkey
                 
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81170  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail Table. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                
               END                                      
               
               IF ISNULL(@c_OldId,'') <> ''
               BEGIN             
                  UPDATE ID WITH (ROWLOCK)
                  SET PalletFlag = @c_OldID
                  WHERE ID = @c_ToID
               END
               ELSE
               BEGIN
               UPDATE ID WITH (ROWLOCK)
                  SET PalletFlag = @c_ID
                  WHERE ID = @c_ToID
               END   
               
               SET @n_err = @@ERROR          
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81180  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update ID Table. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
               END                                                              
            END
                                    
            FETCH NEXT FROM @CUR_PICK INTO @c_Pickdetailkey, @n_PickQty
         END
         CLOSE @CUR_PICK
         DEALLOCATE @CUR_PICK
         
         IF ISNULL(@c_OldId,'') = ''  
            SET @c_OldID = @c_ID
                
         INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                        StorerKey,      SKU,         FromLOC,         ToLOC,
                        Lot,            Id,          Qty,             UOM,
                        PackKey,        Priority,    QtyMoved,        QtyInPickLOC,
                        RefNo,          Confirmed,   ReplenNo,        Wavekey,
                        Remark,         OriginalQty, OriginalFromLoc, ToID)
         VALUES (
                        @c_ReplenishmentKey,         '',
                        @c_StorerKey,   @c_Sku,      @c_FromLoc,      @c_ToLoc,
                        @c_Lot,         @c_ToId,       @n_Qty,          @c_UOM,
                        @c_Packkey,     '5',             0,               0,
                        @c_DropID,      'N',         @c_Wavekey,    @c_WaveKey,
                        '',                 @n_Qty,      'ispRLWAV38',    @c_ToId
                 )
         
         SET @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 81190 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                
         END                        
                
         FETCH NEXT FROM @CUR_PICK_RPL INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Packkey, @c_UOM
      END    
      CLOSE @CUR_PICK_RPL    
      DEALLOCATE @CUR_PICK_RPL              
   END
    
   --NJOW01  
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_Userdefine01,'') <> '' 
   BEGIN
      EXEC dbo.ispGenTransmitLog2 'WSWAVERLS1', @c_Wavekey, '', @c_StorerKey, ''  
        , @b_success OUTPUT  
        , @n_err OUTPUT  
        , @c_errmsg OUTPUT
        
      IF @b_Success <> 1
         SET @n_continue = 3            
   END      
    
   -----Update Wave Status-----    
   IF @n_continue = 1 or @n_continue = 2      
   BEGIN          
      UPDATE WAVE WITH (ROWLOCK)    
       SET TMReleaseFlag = 'Y'               
        ,  TrafficCop = NULL                   
         , EditWho = SUSER_SNAME()    
         , EditDate= GETDATE()     
      WHERE WAVEKEY = @c_wavekey      
    
      SET @n_err = @@ERROR      
      IF @n_err <> 0      
      BEGIN      
        SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
      END      
   END      
  
   -- Make sure all pickdetail have taskdetailkey stamped (Chee01)  
   IF ISNULL(@c_Userdefine01,'') = ''  --NJOW01
   BEGIN
      SET @n_Cnt = 0
      ;WITH PICK (PickDetailKey, TaskDetailKey)
       AS ( SELECT PD.PickDetailKey, TaskDetailKey = ISNULL(PD.TaskDetailKey,'')
            FROM WAVEDETAIL WD  WITH (NOLOCK)     
            JOIN PICKDETAIL PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey) 
            JOIN LOC            WITH (NOLOCK) ON (PD.Loc = LOC.Loc) 
            WHERE WD.Wavekey = @c_Wavekey  
            AND PD.Storerkey = @c_Storerkey
            AND PD.[Status] < '5' 
            AND NOT EXISTS (  SELECT 1 FROM STRING_SPLIT(@c_Userdefine01, ',') WHERE [Value] = LOC.PutawayZone )  
           )
      
      SELECT @n_Cnt = COUNT(1)
      FROM PICK P
      WHERE P.Taskdetailkey = ''
      
      IF @n_Cnt = 1
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 81210  
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': TaskDetailkey not updated to pickdetail. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '         
         GOTO RETURN_SP    
      END   
   END
    
   RETURN_SP:    
    
   WHILE @@TRANCOUNT < @n_starttcnt    
   BEGIN      
      BEGIN TRAN      
   END      
    
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_success = 0      
    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt      
      BEGIN        
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_starttcnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV38'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN      
   END      
   ELSE      
   BEGIN      
      SET @b_success = 1      
      WHILE @@TRANCOUNT > @n_starttcnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END    
    
   RELEASE_TASKS:    
       
   --function to insert taskdetail    
   IF (@n_continue = 1 or @n_continue = 2)     
   BEGIN   
      SET @c_LogicalFromLoc = ''  
      SELECT TOP 1 @c_AreaKey = AreaKey    
                 , @c_LogicalFromLoc = ISNULL(RTRIM(LogicalLocation),'')    
      FROM LOC        LOC WITH (NOLOCK)    
      JOIN AREADETAIL ARD WITH (NOLOCK) ON (LOC.PutawayZone = ARD.PutawayZone)    
      WHERE LOC.Loc = @c_FromLoc     
    
      IF ISNULL(@c_Message03,'') = '' AND @c_TaskType <> 'RPF'
      BEGIN
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81220   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty Message03 is not allowed. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '               
         GOTO RETURN_SP    
      END

      IF ISNULL(@c_Areakey,'') = ''
      BEGIN
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81230   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty Areakey is not allowed. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '               
         GOTO RETURN_SP    
      END
          
             
      SET @b_success = 1      
      EXECUTE   nspg_getkey      
               'TaskDetailKey'      
              , 10      
              , @c_taskdetailkey OUTPUT      
              , @b_success       OUTPUT      
              , @n_err           OUTPUT      
              , @c_errmsg        OUTPUT      
      IF NOT @b_success = 1      
      BEGIN      
         SET @n_continue = 3      
         GOTO RETURN_SP    
      END      

      IF @b_success = 1      
      BEGIN        
         INSERT INTO TASKDETAIL      
         (      
         TaskDetailKey      
         ,TaskType      
         ,Storerkey      
         ,Sku      
         ,UOM      
         ,UOMQty      
         ,Qty      
         ,SystemQty    
         ,Lot      
         ,FromLoc      
         ,FromID      
         ,ToLoc      
         ,ToID     
         ,SourceType      
         ,SourceKey      
         ,Priority      
         ,SourcePriority      
         ,Status      
         ,LogicalFromLoc      
         ,LogicalToLoc      
         ,PickMethod    
         ,Wavekey    
         ,Listkey      
         ,Areakey    
         ,Message03   
         ,CaseID 
         ,LoadKey    
         ,OrderKey 
         ,FinalLoc      --v1.8
         )      
         VALUES      
         (      
          @c_taskdetailkey      
         ,@c_TaskType --Tasktype      
         ,@c_Storerkey      
         ,@c_Sku      
         ,@c_UOM        -- UOM,      
         ,@n_UOMQty     -- UOMQty,      
         ,@n_Qty      
         ,@n_Qty        --systemqty    
         ,@c_Lot       
         ,@c_fromloc       
         ,@c_ID         -- from id      
         ,@c_toloc        
         ,@c_ID         -- to id  
         ,@c_SourceType --Sourcetype      
         ,@c_Wavekey    --Sourcekey      
         ,@c_Priority   -- Priority        
         ,'9'           -- Sourcepriority      
         ,@c_TaskStatus -- Status      
         ,@c_LogicalFromLoc --Logical from loc      
         ,@c_LogicalToLoc   --Logical to loc      
         ,@c_PickMethod    
         ,@c_Wavekey    
         ,''    
         ,@c_Areakey    
         ,@c_Message03  
         ,@c_UCCNo          -- caseid
         ,@c_LoadKey  
         ,@c_Orderkey 
         ,@c_FinalLoc   -- v1.8                                           
         )    
    
         SET @n_err = @@ERROR     
    
         IF @n_err <> 0      
         BEGIN    
    
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 81240   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
    
            GOTO RETURN_SP    
         END       
      END    
   END    
    
   --Update taskdetailkey/wavekey to pickdetail    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN
      SET @n_ReplenQty = @n_Qty 

      IF @c_TaskType IN ( 'SPK', 'PK' )
      BEGIN
         IF @c_Orderkey = ''
         BEGIN
            SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
            SELECT PD.PickdetailKey    
                  ,PD.Qty    
            FROM #TMP_PICKDETAIL TP WITH (NOLOCK)     
            JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TP.PickDetailkey = PD.PickDetailkey)    
            WHERE TP.WAVEPAZone = 0
            AND TP.PutawayZone NOT IN ('LULUCP')
            AND PD.[Status] = '0'
            AND PD.DropID = ''
            AND (PD.Taskdetailkey = '' OR  PD.Taskdetailkey IS NULL)  
            AND PD.Storerkey = @c_Storerkey    
            AND PD.Sku = @c_sku    
            AND PD.Lot = @c_Lot    
            AND PD.Loc = @c_FromLoc    
            AND PD.ID  = @c_ID    
            ORDER BY PD.PickDetailKey 
         END 
         ELSE
         BEGIN
            SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
            SELECT PD.PickdetailKey    
                  ,PD.Qty    
            FROM #TMP_PICKDETAIL TP WITH (NOLOCK)     
            JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TP.PickDetailkey = PD.PickDetailkey)    
            WHERE TP.WAVEPAZone = 0
            AND TP.PutawayZone NOT IN ('LULUCP')
            AND PD.[Status] = '0'
            AND PD.DropID = ''
            AND (PD.Taskdetailkey = '' OR  PD.Taskdetailkey IS NULL)  
            AND PD.Storerkey = @c_Storerkey    
            AND PD.Sku = @c_sku    
            AND PD.Lot = @c_Lot    
            AND PD.Loc = @c_FromLoc    
            AND PD.ID  = @c_ID    
            AND PD.Orderkey = @c_Orderkey
            ORDER BY PD.PickDetailKey  
         END
      END
      ELSE IF @c_TaskType = 'RPF'
      BEGIN 
         IF @c_UCCNo <> ''    -- BULK ( 1:One UCC Single SKU, 2:One UCC Multi Sku -> Task for Sku & Lot is empty )
         BEGIN
            SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
            SELECT PD.PickdetailKey    
                  ,PD.Qty    
            FROM #TMP_PICKDETAIL TP WITH (NOLOCK)     
            JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TP.PickDetailkey = PD.PickDetailkey)    
            WHERE TP.WAVEPAZone = 0
            AND PD.[Status] = '0'
            AND PD.DropID = @c_UCCNo 
            AND (PD.Taskdetailkey = '' OR  PD.Taskdetailkey IS NULL)  
            AND PD.Storerkey = @c_Storerkey    
            AND PD.Loc = @c_FromLoc    
            AND PD.ID  = @c_ID  
            ORDER BY PD.PickDetailKey  
         END
         ELSE
         BEGIN
            -- Piece Pick (LULUCP and No UCCNo) 
            SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
            SELECT PD.PickdetailKey    
                  ,PD.Qty    
            FROM #TMP_PICKDETAIL TP WITH (NOLOCK)     
            JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TP.PickDetailkey = PD.PickDetailkey)    
            WHERE TP.WAVEPAZone = 0
            AND TP.PutawayZone IN ('LULUCP')
            AND PD.[Status] = '0'
            AND PD.UOM = '7' 
            AND PD.DropID = '' 
            AND (PD.Taskdetailkey = '' OR  PD.Taskdetailkey IS NULL)  
            AND PD.Storerkey = @c_Storerkey  
            --AND PD.Lot = @c_Lot         --@c_Lot is empty in Taskdetail.lot
            AND PD.Sku = @c_Sku           --Wan01
            AND PD.Loc = @c_FromLoc    
            AND PD.ID  = @c_ID  
            AND PD.DropID = @c_UCCNo  
            ORDER BY PD.PickDetailKey  
         END
      END

      OPEN @CUR_PICK      
    
      FETCH NEXT FROM @CUR_PICK INTO @c_PickdetailKey    
                                    ,@n_PickQty    
         
      WHILE @@FETCH_STATUS <> -1 AND @n_ReplenQty > 0     
      BEGIN    
    
         UPDATE PICKDETAIL WITH (ROWLOCK)    
         SET Taskdetailkey = @c_TaskdetailKey    
            ,EditWho = SUSER_SNAME()    
            ,EditDate= GETDATE()     
            ,TrafficCop = NULL    
         WHERE Pickdetailkey = @c_PickdetailKey    
    
         SET @n_err = @@ERROR    
         IF @n_err <> 0     
         BEGIN    
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 81250     
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
            BREAK    
         END     
                   
         SET @n_ReplenQty = @n_ReplenQty - @n_PickQty     
         NEXT_PD:              
         FETCH NEXT FROM @CUR_PICK INTO @c_PickdetailKey    
                                       ,@n_PickQty    
      END    
      CLOSE @CUR_PICK    
      DEALLOCATE @CUR_PICK    
   END  
 
   IF @c_TaskType = 'RPF'
   BEGIN
      
      GOTO TASKREPL  
   END
   ELSE  
   BEGIN
      IF @c_OrderType = 'ECOM'       
         GOTO ECOM                  
      IF @c_OrderType = 'RETAIL'    
         GOTO RETAIL
   END        
END --sp end

GO