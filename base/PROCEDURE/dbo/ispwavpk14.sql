SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispWAVPK14                                         */
/* Creation Date: 21-May-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17084 - SG - THGSG - Wave Auto Assign Temp Dropid [CR]  */
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

CREATE PROC [dbo].[ispWAVPK14]   
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
           @c_Code2             NVARCHAR(50),
           @n_Weight            FLOAT,
           @c_PrevCaseID        NVARCHAR(50) = '',
           @n_TTLCartLVL        INT = 3,
           @n_OrderOnLVL1       INT = 0,
           @n_OrderOnLVL2       INT = 0,
           @n_OrderOnLVL3       INT = 0,
           @n_RowNumber         INT = 0,
           @c_CartLVL           NVARCHAR(10)
                                               
   DECLARE @n_Continue   INT,
           @n_StartTCnt  INT,
           @n_debug      INT,
           @n_Cnt        INT = 1
    
   SET @c_SourceType = 'ispWAVPK14'
    
   IF @n_err =  1
      SET @n_debug = 1
   ELSE IF @n_err = 2
      SET @n_debug = 2
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
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Temp ToteID Codelkup Not Setup (ispWAVPK14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
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
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders per PK Not Setup (Storer.SUSR5) (ispWAVPK14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP 
   END

   IF @n_SUSR5 > @n_CodelkupCnt
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders per PK exceeded Totes per Trolley (ispWAVPK14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
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
         
      CREATE TABLE #TMP_SUM (
         [OrderKey] [nvarchar](10) NOT NULL,
         [Weight]   [FLOAT] NOT NULL DEFAULT ((0.00)) )
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The wave has been pre-cartonized or Started Picking. Not allow to run again. (ispWAVPK14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
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

   --Store Orderkey in Temp Table and calculate Weight SUM(Orders.OriginalQty * Sku.GrossWGT)
   IF @n_continue = 1 or @n_continue = 2
   BEGIN   
      SET @n_Weight   = 0.00
      SET @c_Orderkey = ''

      DECLARE CUR_SUM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PD.OrderKey, SUM(ORDERDETAIL.OriginalQty * ISNULL(SKU.GrossWgt, 0.00) )
      FROM #PickDetail_WIP PD (NOLOCK)
      JOIN SKU (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.Storerkey
      JOIN ORDERDETAIL (NOLOCK) ON ORDERDETAIL.OrderKey = PD.OrderKey 
                               AND ORDERDETAIL.OrderLineNumber = PD.OrderLineNumber
                               AND ORDERDETAIL.SKU = PD.Sku
      WHERE PD.WIP_Refno = @c_SourceType
      GROUP BY PD.OrderKey

      OPEN CUR_SUM  
       
      FETCH NEXT FROM CUR_SUM INTO @c_Orderkey, @n_Weight
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN  
         INSERT INTO #TMP_SUM (OrderKey, [Weight])
         SELECT @c_Orderkey, CASE WHEN ISNULL(@n_Weight,0.00) = 0.00 THEN 0.00 ELSE @n_Weight END

         FETCH NEXT FROM CUR_SUM INTO @c_Orderkey, @n_Weight
      END
      CLOSE CUR_SUM
      DEALLOCATE CUR_SUM

      SET @c_Orderkey = ''
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN   
      CREATE TABLE #TMP_STG1 (
         Orderkey   NVARCHAR(10),
         Loc        NVARCHAR(50) 
      )

      CREATE TABLE #TMP_STG2 (
         Orderkey   NVARCHAR(10),
         Loc        NVARCHAR(50) 
      )

      CREATE TABLE #TMP_STG3 (
         Orderkey   NVARCHAR(10),
         Loc        NVARCHAR(50) 
      )

      CREATE TABLE #TMP_STG4 (
         rowid      INT NOT NULL IDENTITY(1,1), 
         Orderkey   NVARCHAR(10),
         FirstLoc   NVARCHAR(50) NULL,
         SecondLoc  NVARCHAR(50) NULL,
         ThirdLoc   NVARCHAR(50) NULL
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
      SELECT t1.CaseID, COUNT(DISTINCT t1.OrderKey) AS [COUNT]
      INTO #TMP_CountPerCaseID
      FROM #PickDetail_WIP t1 (NOLOCK)
      GROUP BY T1.CaseID

      SELECT t1.CaseID, t1.Orderkey, t2.[Weight], (Row_Number() OVER (PARTITION BY t1.CaseID Order By t1.CaseID ASC, t2.[Weight] ASC) ) AS RowNumber, CAST('Low' AS NVARCHAR(10)) AS CartLVL
      INTO #TMP_CartLVL
      FROM #PickDetail_WIP t1 (NOLOCK)
      JOIN #TMP_SUM t2 (NOLOCK) ON t2.OrderKey = t1.OrderKey
      GROUP BY t1.CaseID, t1.Orderkey, t2.[Weight]
      ORDER BY t1.CaseID ASC, t2.[Weight] ASC
      
      IF @n_debug = 2
      BEGIN
         SELECT CaseID, OrderKey, RowNumber
         FROM #TMP_CartLVL
         ORDER BY CaseID, RowNumber
      END

      SET @n_Count = 0
      DECLARE CUR_GetLVL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT t1.CaseID, t3.[Count]
      FROM #PickDetail_WIP t1 (NOLOCK)
      JOIN #TMP_SUM t2 (NOLOCK) ON t2.OrderKey = t1.OrderKey
      JOIN #TMP_CountPerCaseID t3 (NOLOCK) ON t1.CaseID = t3.CaseID
      GROUP BY t1.CaseID, t3.[Count]
      ORDER BY t1.CaseID

      OPEN CUR_GetLVL  
       
      FETCH NEXT FROM CUR_GetLVL INTO @c_CaseID, @n_Count
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN 
         IF @c_CaseID <> @c_PrevCaseID
      	BEGIN
      		IF @n_Count = @n_SUSR5
      		BEGIN
      			SET @n_OrderOnLVL1 = @n_Count / @n_TTLCartLVL
               SET @n_OrderOnLVL2 = @n_OrderOnLVL1 
               SET @n_OrderOnLVL3 = @n_OrderOnLVL1 
      		END
      		ELSE   --@n_Count < @n_SUSR5
      		BEGIN
      		   SET @n_OrderOnLVL1 = @n_SUSR5 / @n_TTLCartLVL
               SET @n_OrderOnLVL2 = CASE WHEN @n_Count - @n_OrderOnLVL1 < 0 THEN 0 
                                         WHEN @n_Count - @n_OrderOnLVL1 > @n_SUSR5 / @n_TTLCartLVL THEN @n_SUSR5 / @n_TTLCartLVL
                                         ELSE @n_Count - @n_OrderOnLVL1 END
               SET @n_OrderOnLVL3 = CASE WHEN @n_Count - @n_OrderOnLVL1 - @n_OrderOnLVL2 < 0 THEN 0 ELSE @n_Count - @n_OrderOnLVL1 - @n_OrderOnLVL2 END
      		END
         END

         IF @n_debug = 2
         BEGIN
            SELECT @c_CaseID
                  ,@n_OrderOnLVL1
                  ,@n_OrderOnLVL2
      	         ,@n_OrderOnLVL3
         END

         IF @n_OrderOnLVL1 = @n_OrderOnLVL2 AND @n_OrderOnLVL2 = @n_OrderOnLVL3
         BEGIN
            SET @n_RowNumber = 1
            WHILE @n_OrderOnLVL1 > 0
            BEGIN
               UPDATE #TMP_CartLVL
               SET CartLVL = 'High'
               WHERE CaseID = @c_CaseID AND RowNumber = @n_RowNumber
               SET @n_OrderOnLVL1 = @n_OrderOnLVL1 - 1
               SET @n_RowNumber = @n_RowNumber + 1
            END

            WHILE @n_OrderOnLVL2 > 0
            BEGIN
               SET @n_OrderOnLVL2 = @n_OrderOnLVL2 - 1
               SET @n_RowNumber = @n_RowNumber + 1
            END
            
            WHILE @n_OrderOnLVL3 > 0
            BEGIN
               UPDATE #TMP_CartLVL
               SET CartLVL = 'Mid'
               WHERE CaseID = @c_CaseID AND RowNumber = @n_RowNumber
               SET @n_OrderOnLVL3 = @n_OrderOnLVL3 - 1
               SET @n_RowNumber = @n_RowNumber + 1
            END
         END
         ELSE
         BEGIN
            SET @n_RowNumber = 1
            WHILE @n_OrderOnLVL1 > 0
            BEGIN
               UPDATE #TMP_CartLVL
               SET CartLVL = 'High'
               WHERE CaseID = @c_CaseID AND RowNumber = @n_RowNumber
               SET @n_OrderOnLVL1 = @n_OrderOnLVL1 - 1
               SET @n_RowNumber = @n_RowNumber + 1
            END

            SET @n_RowNumber = @n_Count - @n_OrderOnLVL2 + 1

            WHILE @n_OrderOnLVL2 > 0
            BEGIN
               UPDATE #TMP_CartLVL
               SET CartLVL = 'Mid'
               WHERE CaseID = @c_CaseID AND RowNumber = @n_RowNumber
               SET @n_OrderOnLVL2 = @n_OrderOnLVL2 - 1
               SET @n_RowNumber = @n_RowNumber + 1
            END
         END

         FETCH NEXT FROM CUR_GetLVL INTO @c_CaseID, @n_Count
      END
      CLOSE CUR_GetLVL
      DEALLOCATE CUR_GetLVL

      IF @n_debug IN (1,2)
      BEGIN 
         SELECT CaseID, Orderkey, CartLVL
         FROM #TMP_CartLVL
         ORDER BY CaseID, CASE WHEN CartLVL = 'High' THEN 10 
                               WHEN CartLVL = 'Mid'  THEN 20 
                               WHEN CartLVL = 'Low'  THEN 30 
                               ELSE 40 END
      END

      DECLARE CUR_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT TCL.CaseID, TCL.Orderkey, TCL.CartLVL
      FROM #TMP_CartLVL TCL (NOLOCK)
      ORDER BY TCL.CaseID, CASE WHEN TCL.CartLVL = 'High' THEN 10 
                                WHEN TCL.CartLVL = 'Mid'  THEN 20 
                                WHEN TCL.CartLVL = 'Low'  THEN 30 
                                ELSE 40 END

      OPEN CUR_UPDATE  
       
      FETCH NEXT FROM CUR_UPDATE INTO @c_CaseID, @c_Orderkey, @c_CartLVL
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN  
         IF @c_PrevCaseID <> @c_CaseID
         BEGIN
            SET @n_Cnt = 1
         END

         SELECT @c_Code2 = ISNULL(CL.Code2,''),
                @c_Short = ISNULL(CL.Short,'')
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.Listname = 'CUSTPARAM' AND CL.Code = 'TOTE_SEQ' AND CL.Storerkey = @c_Storerkey
         AND CL.Short = @n_Cnt

         IF @n_debug = 2
         BEGIN
            SELECT @c_Orderkey AS ORDERKEY, @c_CartLVL AS CARTLVL, @n_Cnt AS CNT, @c_Code2 AS B_Fax2, @c_Short AS BilledContainerQty, @n_CodelkupCnt AS CODELKUPCNT
         END

         UPDATE ORDERS WITH (ROWLOCK)
         SET ORDERS.B_Fax2 = @c_Code2,
             ORDERS.BilledContainerQty = @c_Short
         WHERE ORDERS.Orderkey = @c_Orderkey

         SET @n_Cnt = @n_Cnt + 1

         SET @c_PrevCaseID = @c_CaseID

         FETCH NEXT FROM CUR_UPDATE INTO @c_CaseID, @c_Orderkey, @c_CartLVL
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
   
   -----Update Orders Per PK into Wave.UserDefine09
   IF @n_continue = 1 or @n_continue = 2
   BEGIN   
      UPDATE WAVE
      SET UserDefine09 = CAST(@n_SUSR5 AS NVARCHAR(10))
      WHERE WaveKey = @c_Wavekey

      SET @n_Err = @@ERROR

      IF @n_Err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38025    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Failed to update Wave.UserDefine09. (ispWAVPK14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
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

   IF OBJECT_ID('tempdb..#TMP_SUM') IS NOT NULL
      DROP TABLE #TMP_SUM

   IF OBJECT_ID('tempdb..#TMP_CountPerCaseID') IS NOT NULL
      DROP TABLE #TMP_CountPerCaseID

   IF OBJECT_ID('tempdb..#TMP_CartLVL') IS NOT NULL
      DROP TABLE #TMP_CartLVL
      
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
	 	EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK14'		
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