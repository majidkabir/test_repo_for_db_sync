SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  ispMBRTK03                                         */  
/* Creation Date:  06-Apr-2013                                          */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 279786-VF Release move tasks - Pack&hold to PnD to Staging  */  
/*                                                                      */  
/* Input Parameters:  @c_Mbolkey  - (Mbol # / Cbol #)                   */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: MBOL/CBOL RMC Release Move Task                           */  
/*            (isp_CMBOLReleaseMoveTask_Wrapper)                        */  
/*            storerconfig: ReleaseCMBOL_MV_SP                          */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver  Purposes                                   */
/* 10-07-2014  TLTING   1.1  (NOLOCK) Bug                               */  
/************************************************************************/  
 /* 
DECLARE @c_MbolKey NVARCHAR(10),     
   @b_Success int ,  
   @n_err     int ,  
   @c_errmsg  NVARCHAR(250)   
      
EXEC ispMBRTK03 '0000578626',@b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
SELECT @b_Success , @n_err , @c_errmsg 
*/

CREATE PROC [dbo].[ispMBRTK03]  
   @c_MbolKey NVARCHAR(10),     
   @b_Success int OUTPUT,  
   @n_err     int OUTPUT,  
   @c_errmsg  NVARCHAR(250) OUTPUT,  
   @n_Cbolkey bigint = 0   
AS  
BEGIN  
   SET NOCOUNT ON   -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue int,  
           @n_StartTranCnt int,  
           @n_Cnt int,
           @c_Storerkey NVARCHAR(15),  
           @c_toloc NVARCHAR(10),  
           @c_toPnD NVARCHAR(10),  
           @c_toloc_task1 NVARCHAR(10),  
           @c_toloc_task2 NVARCHAR(10),  
           @c_fromloc NVARCHAR(10),  
           @c_fromloc_task2 NVARCHAR(10),  
           @c_dropid NVARCHAR(18),  
           @c_taskdetailkey NVARCHAR(10),  
           @c_taskdetailkey2 NVARCHAR(10),  
           @c_AreaKey NVARCHAR(10),   
           @c_CurrMbolkey NVARCHAR(10),  
           @n_movetaskreleased int,
           @c_LocCategory NVARCHAR(10),
           @c_LocAisle NVARCHAR(10),
           @c_Facility NVARCHAR(5)
  
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_movetaskreleased = 0 
     
   CREATE TABLE #TMP_PACKDETAIL  
     ( Pickslipno NVARCHAR(10) NULL,  
       Labelno NVARCHAR(30) NULL)  
              
   DECLARE cur_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT DISTINCT M.Mbolkey, MIN(O.Storerkey)  
       FROM MBOL M (NOLOCK)   
       JOIN MBOLDETAIL MD (NOLOCK) ON M.Mbolkey = MD.Mbolkey  
       JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
       WHERE M.MbolKey = @c_MbolKey   
            OR (@n_Cbolkey > 0 AND ISNULL(@c_Mbolkey,'') = '' AND M.Cbolkey = @n_Cbolkey)    
       GROUP BY M.Mbolkey  
       ORDER BY M.Mbolkey  
       
   OPEN cur_MBOL  
   FETCH NEXT FROM cur_MBOL INTO @c_CurrMbolkey, @c_Storerkey  
     
   BEGIN TRAN   
      
   WHILE @@FETCH_STATUS = 0  
   BEGIN                       
      IF NOT EXISTS(SELECT 1 FROM MBOLDETAIL MD (NOLOCK)   
                    WHERE MD.MbolKey = @c_CurrMbolKey)   
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63501  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Orders being populated into MBOLDetail Of MBOL# " + RTRIM(@c_CurrMbolKey) + " (ispMBRTK03)"  
         GOTO RETURN_SP  
      END  
        
      IF NOT EXISTS(SELECT 1 FROM LOADPLANLANEDETAIL (NOLOCK)  
                      WHERE MbolKey = @c_CurrMbolKey)  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63502  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Lanes/Doors being assigned for the MBOL " + RTRIM(@c_CurrMbolKey) + " (ispMBRTK03)"  
          GOTO RETURN_SP  
      END  
        
      IF EXISTS(SELECT 1 FROM LOADPLANLANEDETAIL WITH (NOLOCK)  
                     JOIN LOC (NOLOCK) ON LOADPLANLANEDETAIL.Loc = LOC.Loc  
                     WHERE MbolKey = @c_CurrMbolKey AND LOC.LocationCategory NOT IN ('STAGING'))  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63503  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Wrong Lanes/Doors being assigned. Only STAGING is allowed at MBOL# " + RTRIM(@c_CurrMbolKey) + " (ispMBRTK03)"  
         GOTO RETURN_SP  
      END  
        
       IF EXISTS(SELECT 1 FROM MBOLDETAIL WITH (NOLOCK)  
                      JOIN PICKDETAIL WITH (NOLOCK) ON MBOLDETAIL.Orderkey = PICKDETAIL.Orderkey  
                      LEFT JOIN PACKHEADER WITH (NOLOCK) ON PICKDETAIL.Pickslipno = PACKHEADER.Pickslipno  
                      WHERE MBOLDETAIL.MbolKey = @c_CurrMbolKey AND PACKHEADER.Pickslipno IS NULL)  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63504  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Complete Pack being created for the MBOL# " + RTRIM(@c_CurrMbolKey) + " (ispMBRTK03)"  
         GOTO RETURN_SP  
      END  
              
      DELETE FROM #TMP_PACKDETAIL  
      
      INSERT INTO #TMP_PACKDETAIL  
      SELECT DISTINCT PD.PickSlipNo, PD.LabelNo  
      FROM MBOLDETAIL MD (NOLOCK)  
      JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
      JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
      JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
      WHERE MD.Mbolkey = @c_CurrMbolkey  
      AND O.SOStatus = 'RELEASED'
        
      SET @c_Toloc = ''  
        
      SELECT TOP 1 @c_Toloc = LOADPLANLANEDETAIL.Loc  
      FROM LOADPLANLANEDETAIL (NOLOCK)  
      JOIN LOC (NOLOCK) ON LOADPLANLANEDETAIL.Loc = LOC.Loc  
      WHERE LOADPLANLANEDETAIL.MbolKey = @c_CurrMbolKey   
      AND LOC.LocationCategory = 'STAGING'  
      ORDER BY LOC.Loc  
                
      IF ISNULL(@c_Toloc,'') = ''  
         SET @c_Toloc = ''    

         DECLARE cur_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
           SELECT DISTINCT DROPID.DROPID, DROPID.Droploc, Loc.LocationCategory, Loc.LocAisle, Loc.Facility  
             FROM MBOLDETAIL WITH (NOLOCK)  
             JOIN PACKHEADER WITH (NOLOCK) ON MBOLDETAIL.Orderkey = PACKHEADER.Orderkey  
             JOIN #TMP_PACKDETAIL PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)   
             JOIN DROPIDDETAIL WITH (NOLOCK) ON (PACKDETAIL.LabelNo = DROPIDDETAIL.Childid)  
             JOIN DROPID WITH (NOLOCK) ON (DROPIDDETAIL.Dropid = DROPID.Dropid)  
             JOIN LOC WITH (NOLOCK) ON (DROPID.Droploc = LOC.Loc)  
             LEFT JOIN TASKDETAIL WITH (NOLOCK) ON (MBOLDETAIL.MBOLKEY = TASKDETAIL.Sourcekey AND TASKDETAIL.SourceType = 'ispMBRTK03'  
                                               AND DROPID.Dropid = TASKDETAIL.FromId AND TASKDETAIL.TaskType ='NMV' AND DROPID.DropLoc = TASKDETAIL.FromLoc)  
             JOIN ORDERS WITH (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey                                               
             WHERE MBOLDETAIL.Mbolkey = @c_CurrMbolkey  
             AND TASKDETAIL.Taskdetailkey IS NULL  
             AND LOC.LocationCategory  IN ('PACK&HOLD')  
             AND DROPID.Status = '0'   
             AND ORDERS.SOStatus = 'RELEASED'

          OPEN cur_TASK  
          FETCH NEXT FROM cur_TASK INTO @c_DropId, @c_FromLoc, @c_LocCategory, @c_LocAisle, @c_Facility
        
          WHILE @@FETCH_STATUS = 0  
          BEGIN  
          	 SET @c_toPnD = ''
          	 
             SELECT TOP 1 @c_toPnD=LOC.Loc, @n_Cnt=COUNT(DISTINCT DROPID.DropID) + COUNT(DISTINCT TASKDETAIL.ToID) 
             FROM LOC (NOLOCK)
             LEFT JOIN DROPID (NOLOCK) ON LOC.Loc = DROPID.DropLoc AND DROPID.Status <> '9'   -- PnD occupied by dropid
             LEFT JOIN TASKDETAIL (NOLOCK) ON TASKDETAIL.ToLoc = LOC.Loc AND TASKDETAIL.SourceType = 'ispMBRTK03' AND TASKDETAIL.TaskType ='NMV'  --PnD pending move in by task
                                              AND TASKDETAIL.Status <> '9'  
             WHERE LOC.LocationCategory = 'PND_OUT'
             AND LOC.LocAisle = @c_LocAisle
             AND LOC.Facility = @c_Facility
             GROUP BY LOC.Loc
             ORDER BY 2, LOC.Loc   -- Sort by less occupied        
             
             IF ISNULL(@c_ToPnD,'') <> ''
             BEGIN
             	 --from VNC -> PnD -> Staging
             	 SET @c_fromloc_task2 = @c_ToPnD
             	 SET @c_toloc_task1 = @c_ToPnD
             	 SET @c_toloc_task2 = @c_ToLoc
             END
             ELSE
             BEGIN
             	 --from VNC -> Staging
             	 SET @c_fromloc_task2 = ''
             	 SET @c_toloc_task1 = @c_ToLoc
             	 SET @c_toloc_task2 = ''
             END
             
             --From VNC To PnD If found PnD Loc else from VNC to Staging
             SET @n_movetaskreleased =@n_movetaskreleased + 1   
             SELECT @c_AreaKey = AD.AreaKey FROM AreaDetail AD WITH (NOLOCK)  
             INNER JOIN Loc Loc WITH (NOLOCK) ON Loc.PutawayZone = AD.PutawayZone  
             WHERE Loc.Loc = @c_FromLoc  
        
             SELECT @b_success = 1  
             EXECUTE nspg_getkey  
             "TaskDetailKey"  
             , 10  
             , @c_taskdetailkey OUTPUT  
             , @b_success OUTPUT  
             , @n_err OUTPUT  
             , @c_errmsg OUTPUT  
               
             IF @b_success <> 1  
             BEGIN  
                SELECT @n_continue = 3  
                GOTO RETURN_SP  
             END  
        
             INSERT TASKDETAIL  
             (  
               TaskDetailKey  
              ,TaskType  
              ,Storerkey  
              ,Sku  
              ,UOM  
              ,UOMQty  
              ,Qty  
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
              ,AreaKey   
              ,Message02
             )  
             VALUES  
             (  
               @c_taskdetailkey  
              ,'NMV' --Tasktype  
              ,@c_Storerkey  
              ,'' --sku  
              ,'' -- UOM,  
              ,0  -- UOMQty,  
              ,0  -- Qty  
              ,'' -- lot  
              ,@c_fromloc -- from loc  
              ,@c_dropid -- from id  
              ,@c_toloc_task1 -- to loc  
              ,@c_dropid -- to id  
              ,'ispMBRTK03' --Sourcetype  
              ,@c_CurrMbolkey --Sourcekey  
              ,'5' -- Priority  
              ,'9' -- Sourcepriority  
              ,'0' -- Status  
              ,@c_FromLoc --Logical from loc  
              ,@c_toloc_task1 --Logical to loc  
              ,'FP' --pickmethod  
              ,@c_AreaKey   
              ,@c_LocCategory
             )  
        
             SELECT @n_err = @@ERROR  
        
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @n_err = 63505  
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert TASKDETAIL Failed. (ispMBRTK03)"  
                GOTO RETURN_SP  
             END  
             
             --From PnD To Staging If found PnD Loc
             IF ISNULL(@c_ToPnD,'') <> ''
             BEGIN
                SET @n_movetaskreleased =@n_movetaskreleased + 1   
                SELECT @b_success = 1  
                EXECUTE nspg_getkey  
                "TaskDetailKey"  
                , 10  
                , @c_taskdetailkey2 OUTPUT  
                , @b_success OUTPUT  
                , @n_err OUTPUT  
                , @c_errmsg OUTPUT  
                  
                IF @b_success <> 1  
                BEGIN  
                  SELECT @n_continue = 3  
                     GOTO RETURN_SP  
                END  
                
                INSERT TASKDETAIL  
                (  
                  TaskDetailKey  
                 ,TaskType  
                 ,Storerkey  
                 ,Sku  
                 ,UOM  
                 ,UOMQty  
                 ,Qty  
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
                 ,AreaKey   
                 ,Message02
                 ,Listkey
                )  
                VALUES  
                (  
                  @c_taskdetailkey2  
                 ,'NMV' --Tasktype  
                 ,@c_Storerkey  
                 ,'' --sku  
                 ,'' -- UOM,  
                 ,0  -- UOMQty,  
                 ,0  -- Qty  
                 ,'' -- lot  
                 ,@c_fromloc_task2 -- from loc  
                 ,@c_dropid -- from id  
                 ,@c_toloc_task2 -- to loc  
                 ,@c_dropid -- to id  
                 ,'ispMBRTK03' --Sourcetype  
                 ,@c_CurrMbolkey --Sourcekey  
                 ,'5' -- Priority  
                 ,'9' -- Sourcepriority  
                 ,'0' -- Status  
                 ,@c_FromLoc --Logical from loc  
                 ,@c_toloc_task2 --Logical to loc  
                 ,'FP' --pickmethod  
                 ,@c_AreaKey   
                 ,RTRIM(@c_LocCategory) + '-PND_OUT'
                 ,@c_taskdetailkey  -- from vnc -> pnd taskdetailkey
                )  
                
                SELECT @n_err = @@ERROR  
                
                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @n_err = 63506  
                   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert TASKDETAIL Failed. (ispMBRTK03)"  
                   GOTO RETURN_SP  
                END  
             END
        
             FETCH NEXT FROM cur_TASK INTO @c_DropId, @c_FromLoc, @c_LocCategory, @c_LocAisle, @c_Facility
          END  
          CLOSE cur_TASK  
          DEALLOCATE cur_TASK  
        
      FETCH NEXT FROM cur_MBOL INTO @c_CurrMbolkey, @c_Storerkey  
   END --While mbolkey    
   CLOSE cur_MBOL  
   DEALLOCATE cur_MBOL  
END  
  
RETURN_SP:  
  
IF @n_continue=3  -- Error Occured - Process And Return  
BEGIN  
 SELECT @b_success = 0  
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt  
 BEGIN  
  ROLLBACK TRAN  
 END  
 ELSE  
 BEGIN  
  WHILE @@TRANCOUNT > @n_StartTranCnt  
  BEGIN  
   COMMIT TRAN  
  END  
 END  
 execute nsp_logerror @n_err, @c_errmsg, 'ispMBRTK03'  
 --RAISERROR @n_err @c_errmsg  
 RETURN  
END  
ELSE  
BEGIN  
 IF @n_movetaskreleased > 0  
    SELECT @c_ErrMsg = LTRIM(RTRIM(CONVERT(VarChar(10),@n_movetaskreleased))) + ' Move Tasks Released'  
 ELSE   
    SELECT @c_ErrMsg = 'No Move Task Found For Release'  
   
 SELECT @b_success = 1  
 WHILE @@TRANCOUNT > @n_StartTranCnt  
 BEGIN  
  COMMIT TRAN  
 END  
 RETURN  
END  

GO