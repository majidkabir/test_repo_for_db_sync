SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  ispMBRTK02                                         */  
/* Creation Date:  23-Oct-2012                                          */  
/* Copyright: IDS                                                       */  
/* Written by:  NJOW                                                    */  
/*                                                                      */  
/* Purpose:  257389-FNPC Release move tasks                             */  
/*                                                                      */  
/* Input Parameters:  @c_Mbolkey  - (Mbol #)                            */  
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
  
CREATE PROC [dbo].[ispMBRTK02]  
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
           @c_Storerkey NVARCHAR(15),  
           @c_toloc NVARCHAR(10),  
           @c_fromloc NVARCHAR(10),  
           @c_dropid NVARCHAR(18),  
           @c_taskdetailkey NVARCHAR(10),  
           @c_AreaKey NVARCHAR(10),   
           @c_Svalue NVARCHAR(10),  
           @c_CurrMbolkey NVARCHAR(10),  
           @n_movetaskreleased int,
           @c_LocCategory NVARCHAR(10)
  
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
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Orders being populated into MBOLDetail Of MBOL# " + RTRIM(@c_CurrMbolKey) + " (ispMBRTK02)"  
         GOTO RETURN_SP  
      END  
        
       /*IF NOT EXISTS(SELECT 1 FROM LOADPLANLANEDETAIL (NOLOCK)  
                      WHERE MbolKey = @c_CurrMbolKey)  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63502  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Lanes/Doors being assigned for the MBOL " + RTRIM(@c_CurrMbolKey) + " (ispMBRTK02)"  
          GOTO RETURN_SP  
      END*/  
        
      IF EXISTS(SELECT 1 FROM LOADPLANLANEDETAIL WITH (NOLOCK)  
                     JOIN LOC (NOLOCK) ON LOADPLANLANEDETAIL.Loc = LOC.Loc  
                     WHERE MbolKey = @c_CurrMbolKey AND LOC.LocationCategory NOT IN ('STAGING','QC'))  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63503  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Wrong Lanes/Doors being assigned. Only STAGING/QC is allowed at MBOL# " + RTRIM(@c_CurrMbolKey) + " (ispMBRTK02)"  
         GOTO RETURN_SP  
      END  
        
       IF EXISTS(SELECT 1 FROM MBOLDETAIL WITH (NOLOCK)  
                      JOIN PICKDETAIL WITH (NOLOCK) ON MBOLDETAIL.Orderkey = PICKDETAIL.Orderkey  
                      --LEFT JOIN REFKEYLOOKUP WITH (NOLOCK) ON PICKDETAIL.Pickdetailkey = REFKEYLOOKUP.Pickdetailkey  
                      LEFT JOIN PACKHEADER WITH (NOLOCK) ON PICKDETAIL.Pickslipno = PACKHEADER.Pickslipno  
                      WHERE MBOLDETAIL.MbolKey = @c_CurrMbolKey AND PACKHEADER.Pickslipno IS NULL)  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63504  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Complete Pack being created for the MBOL# " + RTRIM(@c_CurrMbolKey) + " (ispMBRTK02)"  
         GOTO RETURN_SP  
      END  
                
      SELECT @c_Svalue = Svalue   
      FROM STORERCONFIG (NOLOCK)  
      WHERE Storerkey = @c_Storerkey  
      AND Configkey = 'MASTERPACK'  
        
      DELETE FROM #TMP_PACKDETAIL  
        
      INSERT INTO #TMP_PACKDETAIL  
      SELECT DISTINCT PD.PickSlipNo,    
            CASE WHEN ISNULL(PD.Refno,'') <> '' AND ISNULL(PD.Refno2,'') <> '' AND @c_Svalue = '1' THEN  
                             PD.Refno2 ELSE PD.LabelNo END AS LabelNo  
      FROM MBOLDETAIL MD (NOLOCK)  
      JOIN PICKDETAIL PICKD (NOLOCK) ON MD.Orderkey = PICKD.Orderkey  
      JOIN REFKEYLOOKUP RF (NOLOCK) ON PICKD.Pickdetailkey = RF.Pickdetailkey  
      JOIN PACKHEADER PH (NOLOCK) ON RF.Pickslipno = PH.Pickslipno  
      JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
     WHERE MD.Mbolkey = @c_CurrMbolkey  
        
      SET @c_Toloc = ''  
        
      SELECT TOP 1 @c_Toloc = LOADPLANLANEDETAIL.Loc  
      FROM LOADPLANLANEDETAIL (NOLOCK)  
      JOIN LOC (NOLOCK) ON LOADPLANLANEDETAIL.Loc = LOC.Loc  
      WHERE LOADPLANLANEDETAIL.MbolKey = @c_CurrMbolKey   
      AND LOC.LocationCategory = 'STAGING'  
      ORDER BY LOC.Loc  
        
      IF ISNULL(@c_Toloc,'') = ''  
      BEGIN  
        SELECT TOP 1 @c_Toloc = LOADPLANLANEDETAIL.Loc  
        FROM LOADPLANLANEDETAIL (NOLOCK)  
        JOIN LOC (NOLOCK) ON LOADPLANLANEDETAIL.Loc = LOC.Loc  
        WHERE LOADPLANLANEDETAIL.MbolKey = @c_CurrMbolKey   
        AND LOC.LocationCategory = 'QC'  
        ORDER BY LOC.Loc  
      END  
        
      IF ISNULL(@c_Toloc,'') = '' -- To PACK&HOLD Loc will be assigned by RDT  
         SET @c_Toloc = ''    
        
      DECLARE cur_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        SELECT DISTINCT DROPID.DROPID, DROPID.Droploc, Loc.LocationCategory  
          FROM MBOLDETAIL WITH (NOLOCK)  
          JOIN PICKDETAIL WITH (NOLOCK) ON MBOLDETAIL.Orderkey = PICKDETAIL.Orderkey  
          JOIN REFKEYLOOKUP WITH (NOLOCK) ON PICKDETAIL.Pickdetailkey = REFKEYLOOKUP.Pickdetailkey  
          JOIN PACKHEADER WITH (NOLOCK) ON REFKEYLOOKUP.Pickslipno = PACKHEADER.Pickslipno  
          JOIN #TMP_PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)   
          JOIN DROPIDDETAIL (NOLOCK) ON (PACKDETAIL.LabelNo = DROPIDDETAIL.Childid)  
          JOIN DROPID WITH (NOLOCK) ON (DROPIDDETAIL.Dropid = DROPID.Dropid)  
          JOIN LOC WITH (NOLOCK) ON (DROPID.Droploc = LOC.Loc)  
          LEFT JOIN TASKDETAIL WITH (NOLOCK) ON (MBOLDETAIL.MBOLKEY = TASKDETAIL.Sourcekey AND TASKDETAIL.SourceType = 'ispMBRTK02'  
                                            AND DROPID.Dropid = TASKDETAIL.FromId AND TASKDETAIL.TaskType ='NMV')  
          WHERE MBOLDETAIL.Mbolkey = @c_CurrMbolkey  
          AND TASKDETAIL.Taskdetailkey IS NULL  
          AND LOC.LocationCategory NOT IN ('PACK&HOLD','QC','STAGING')  
          AND DROPID.Status = '0'   
        
          OPEN cur_TASK  
          FETCH NEXT FROM cur_TASK INTO @c_DropId, @c_FromLoc, @c_LocCategory
        
          WHILE @@FETCH_STATUS = 0  
          BEGIN  
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
              ,@c_toloc -- to loc  
              ,@c_dropid -- to id  
              ,'ispMBRTK02' --Sourcetype  
              ,@c_CurrMbolkey --Sourcekey  
              ,'5' -- Priority  
              ,'9' -- Sourcepriority  
              ,'0' -- Status  
              ,@c_FromLoc --Logical from loc  
              ,@c_ToLoc --Logical to loc  
              ,'FP' --pickmethod  
              ,@c_AreaKey   
              ,@c_LocCategory
             )  
        
             SELECT @n_err = @@ERROR  
        
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @n_err = 63505  
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert TASKDETAIL Failed. (ispMBRTK02)"  
                GOTO RETURN_SP  
             END  
        
             FETCH NEXT FROM cur_TASK INTO @c_DropId, @c_FromLoc, @c_LocCategory
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
 execute nsp_logerror @n_err, @c_errmsg, 'ispMBRTK02'  
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