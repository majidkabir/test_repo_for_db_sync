SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispWAVPK11                                         */
/* Creation Date: 07-Jul-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-14129 - SG - THGBT - Wave Auto Assign Temp ToteID       */
/*                                                                      */
/* Called By: Wave - Configkey - WAVGENPACKFROMPICKED_SP                */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispWAVPK11]   
   @c_Wavekey   NVARCHAR(10),  
   @b_Success   INT      OUTPUT,
   @n_Err       INT      OUTPUT, 
   @c_ErrMsg    NVARCHAR(250) OUTPUT  
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @c_Storerkey         NVARCHAR(15),
           @c_Sku               NVARCHAR(20),
           @c_Sku2              NVARCHAR(20),
           @c_UOM               NVARCHAR(10),
           @n_Count             INT = 1,
           @n_PKCount           INT = 1,
           @c_SourceType        NVARCHAR(20),
           @c_PrevOrderkey      NVARCHAR(10),
           @c_Orderkey          NVARCHAR(10),
           @n_SUSR5             INT = 0,
           @n_CodelkupCnt       INT = 0,
           @c_CaseID            NVARCHAR(50),
           @c_Short             NVARCHAR(50),
           @c_Code2             NVARCHAR(50)
                                               
   DECLARE @n_Continue   INT,
           @n_StartTCnt  INT,
           @n_debug      INT,
           @n_Cnt        INT = 1
    
   SET @c_SourceType = 'ispWAVPK11'
    
   IF @n_err =  1
      SET @n_debug = 1
   ELSE
      SET @n_debug = 0		 
                                                      
   SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_success = 1 
	 
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   SELECT @c_Storerkey = OH.Storerkey
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = WD.Orderkey
   WHERE WD.Wavekey = @c_Wavekey

   --Check Codelkup Count
   SELECT @n_CodelkupCnt = COUNT(DISTINCT CL.Short)
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Listname = 'CUSTPARAM' AND CL.Code = 'TOTE_SEQ' AND CL.Storerkey = @c_Storerkey

   IF @n_CodelkupCnt = 0
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38000     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Temp ToteID Codelkup Not Setup (ispWAVPK11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP 
   END

   --Check Storer.SUSR5
   SELECT @n_SUSR5 = CASE WHEN ISNUMERIC(ST.SUSR5) = 1 THEN ST.SUSR5 ELSE 0 END
   FROM Storer ST (NOLOCK)
   WHERE ST.Storerkey = @c_Storerkey

   IF @n_SUSR5 = 0
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders per PK Not Setup (Storer.SUSR5) (ispWAVPK11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP 
   END

   IF @n_SUSR5 > @n_CodelkupCnt
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders per PK exceeded Totes per Trolley (ispWAVPK11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP 
   END
     
   --Create temporary table
   IF @n_continue IN(1,2)
   BEGIN    
      CREATE TABLE #PickDetail_WIP(
      	[PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,
      	[CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),
      	[PickHeaderKey] [nvarchar](18) NOT NULL,
      	[OrderKey] [nvarchar](10) NOT NULL,
      	[OrderLineNumber] [nvarchar](5) NOT NULL,
      	[Lot] [nvarchar](10) NOT NULL,
      	[Storerkey] [nvarchar](15) NOT NULL,
      	[Sku] [nvarchar](20) NOT NULL,
      	[AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),
      	[UOM] [nvarchar](10) NOT NULL DEFAULT (' '),
      	[UOMQty] [int] NOT NULL DEFAULT ((0)),
      	[Qty] [int] NOT NULL DEFAULT ((0)),
      	[QtyMoved] [int] NOT NULL DEFAULT ((0)),
      	[Status] [nvarchar](10) NOT NULL DEFAULT ('0'),
      	[DropID] [nvarchar](20) NOT NULL DEFAULT (''),
      	[Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),
      	[ID] [nvarchar](18) NOT NULL DEFAULT (' '),
      	[PackKey] [nvarchar](10) NULL DEFAULT (' '),
      	[UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),
      	[CartonGroup] [nvarchar](10) NULL,
      	[CartonType] [nvarchar](10) NULL,
      	[ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
      	[DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
      	[ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
      	[DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
      	[PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
      	[WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
      	[EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
      	[AddDate] [datetime] NOT NULL DEFAULT (getdate()),
      	[AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
      	[EditDate] [datetime] NOT NULL DEFAULT (getdate()),
      	[EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
      	[TrafficCop] [nvarchar](1) NULL,
      	[ArchiveCop] [nvarchar](1) NULL,
      	[OptimizeCop] [nvarchar](1) NULL,
      	[ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
      	[PickSlipNo] [nvarchar](10) NULL,
      	[TaskDetailKey] [nvarchar](10) NULL,
      	[TaskManagerReasonKey] [nvarchar](10) NULL,
      	[Notes] [nvarchar](4000) NULL,
      	[MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
      	[WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
         [Channel_ID] [bigint] NULL DEFAULT ((0)))	         
   END
   
   --Validation            
   IF @n_continue IN(1,2) 
   BEGIN   	
      IF EXISTS (SELECT 1
                 FROM WAVEDETAIL WD (NOLOCK)
                 JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey   
                 JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
                 WHERE WD.Wavekey = @c_Wavekey
                 AND (ISNULL(PD.CaseID,'') <> ''
                 OR PD.Status >= 3))
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The wave has been pre-cartonized or Started Picking. Not allow to run again. (ispWAVPK11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END
   END
   
   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
           @c_Loadkey               = ''
          ,@c_Wavekey               = @c_wavekey  
          ,@c_WIP_RefNo             = @c_SourceType 
          ,@c_PickCondition_SQL     = ''
          ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
          ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
          ,@b_Success               = @b_Success OUTPUT
          ,@n_Err                   = @n_Err     OUTPUT 
          ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
          
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END          
      BEGIN
         UPDATE #PickDetail_WIP SET CaseID = ''
      END
   END   

   IF @n_continue = 1 or @n_continue = 2
   BEGIN   
      CREATE TABLE #TMP_STG1 (
         Orderkey   NVARCHAR(10),
         Loc        NVARCHAR(20) 
         )

      CREATE TABLE #TMP_STG2 (
         Orderkey   NVARCHAR(10),
         Loc        NVARCHAR(20) 
         )

      CREATE TABLE #TMP_STG3 (
         Orderkey   NVARCHAR(10),
         Loc        NVARCHAR(20) 
         )

      CREATE TABLE #TMP_STG4 (
         rowid      INT NOT NULL IDENTITY(1,1), 
         Orderkey   NVARCHAR(10),
         FirstLoc   NVARCHAR(20) NULL,
         SecondLoc  NVARCHAR(20) NULL,
         ThirdLoc   NVARCHAR(20) NULL
         )

      INSERT INTO #TMP_STG1
      SELECT PD.Orderkey, LOC.LogicalLocation
      FROM #PICKDETAIL_WIP PD (NOLOCK)
      JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
      WHERE PD.Wavekey = @c_Wavekey

      INSERT INTO #TMP_STG2    
      SELECT b.Orderkey,    
      CAST(STUFF((SELECT TOP 3 ',' + RTRIM(a.Loc) FROM #TMP_STG1 a where a.Orderkey = b.Orderkey ORDER BY a.Orderkey, a.Loc FOR XML PATH('')),1,1,'' ) AS NVARCHAR(250)) AS Loc 
      FROM #TMP_STG1 b    
      GROUP BY b.Orderkey

      INSERT INTO #TMP_STG3    
      SELECT b.Orderkey,    
             b.loc
      FROM #TMP_STG2 b    
      GROUP BY b.Orderkey, b.loc
      ORDER BY CAST(SUBSTRING(b.loc,5,4) AS INT)

      INSERT INTO #TMP_STG4
      SELECT Orderkey,     
             (SELECT ColValue FROM dbo.fnc_delimsplit (',',Loc) WHERE SeqNo = 1) AS FirstLoc   ,     
             (SELECT ColValue FROM dbo.fnc_delimsplit (',',Loc) WHERE SeqNo = 2) AS SecondLoc  ,     
             (SELECT ColValue FROM dbo.fnc_delimsplit (',',Loc) WHERE SeqNo = 3) AS ThirdLoc      
      FROM #TMP_STG3    
      ORDER BY FirstLoc,     
               SecondLoc,    
               ThirdLoc  
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN   	 
      DECLARE CUR_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT t.Orderkey
      FROM #TMP_STG4 t 
      GROUP BY t.Orderkey, t.rowid
      ORDER BY t.rowid

      OPEN CUR_ORDERS  
       
      FETCH NEXT FROM CUR_ORDERS INTO @c_Orderkey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN      	
         IF @c_Orderkey <> @c_PrevOrderkey
         BEGIN
            IF @n_PKCount > @n_SUSR5   --8
            BEGIN
               SET @n_Count = @n_Count + 1
               SET @n_PKCount = 1
            END

            UPDATE #PickDetail_WIP
            SET CaseID = 'PK' + RIGHT('00' + CAST(@n_Count AS NVARCHAR(5)), 2)
            WHERE Orderkey = @c_Orderkey

            SET @n_PKCount = @n_PKCount + 1
         END

         SET @c_PrevOrderkey = @c_Orderkey

         FETCH NEXT FROM CUR_ORDERS INTO @c_Orderkey
      END
   END

   SET @c_Orderkey = ''

   IF @n_continue = 1 or @n_continue = 2
   BEGIN   	 
      DECLARE CUR_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT t1.CaseID, t1.Orderkey
      FROM #PickDetail_WIP t1
      GROUP BY t1.CaseID, t1.Orderkey
      ORDER BY t1.CaseID, t1.Orderkey

      OPEN CUR_UPDATE  
       
      FETCH NEXT FROM CUR_UPDATE INTO @c_CaseID, @c_Orderkey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN      	
         SELECT @c_Code2 = ISNULL(CL.Code2,''),
                @c_Short = ISNULL(CL.Short,'')
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.Listname = 'CUSTPARAM' AND CL.Code = 'TOTE_SEQ' AND CL.Storerkey = @c_Storerkey
         AND CL.Short = @n_Cnt

         UPDATE ORDERS WITH (ROWLOCK)
         SET ORDERS.B_Fax2 = @c_Code2,
             ORDERS.BilledContainerQty = @c_Short
         WHERE ORDERS.Orderkey = @c_Orderkey

         IF @n_Cnt >= @n_CodelkupCnt
         BEGIN
            SET @n_Cnt = 1
         END
         ELSE
         BEGIN
            SET @n_Cnt = @n_Cnt + 1
         END

         FETCH NEXT FROM CUR_UPDATE INTO @c_CaseID, @c_Orderkey
      END
   END

   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN   	 
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_Wavekey               = @c_Wavekey 
           ,@c_WIP_RefNo             = @c_SourceType 
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT 
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
          
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END             
   END      
         
QUIT_SP:
   IF OBJECT_ID('tempdb..#PickDetail_WIP') IS NOT NULL
   DROP TABLE #PickDetail_WIP

   IF OBJECT_ID('tempdb..#TMP_STG1') IS NOT NULL
      DROP TABLE #TMP_STG1

   IF OBJECT_ID('tempdb..#TMP_STG2') IS NOT NULL
      DROP TABLE #TMP_STG2

   IF OBJECT_ID('tempdb..#TMP_STG3') IS NOT NULL
      DROP TABLE #TMP_STG3

   IF OBJECT_ID('tempdb..#TMP_STG4') IS NOT NULL
      DROP TABLE #TMP_STG4

   IF CURSOR_STATUS('LOCAL', 'CUR_ORDERS') IN (0 , 1)
   BEGIN
      CLOSE CUR_ORDERS
      DEALLOCATE CUR_ORDERS   
   END
 
   IF CURSOR_STATUS('LOCAL', 'CUR_UPDATE') IN (0 , 1)
   BEGIN
      CLOSE CUR_UPDATE
      DEALLOCATE CUR_UPDATE   
   END

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
	 	EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK11'		
	 	RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	 	--RAISERROR @nErr @cErrmsg
	 	RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	 	WHILE @@TRANCOUNT > @n_StartTCnt
	 	BEGIN
	 		COMMIT TRAN
	 	END
      RETURN
   END  	 	 
END

GO