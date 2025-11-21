SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispMBRTK01                                         */
/* Creation Date:  11-Nov-2011                                          */
/* Copyright: IDS                                                       */
/* Written by:  NJOW                                                    */
/*                                                                      */
/* Purpose:  SOS#229328 - MBOL Release Task                             */
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
/* Called By:  MBOL RMC Release Pick Task                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 21-12-2011  ChewKP   1.1  Add AreaKey for TaskDetail (ChewKP01)      */
/* 07-05-2012  Ung      1.2  SOS243691 Chg DropID.Status 5 to 3 (ung01) */
/* 21-06-2012  NJOW01   1.3  Cater for master carton                    */
/* 23-10-2012  NJOW02   1.4  Get staging location only from lane assign */
/* 10-07-2014  TLTING   1.5  (NOLOCK) Bug                               */
/************************************************************************/

CREATE PROC [dbo].[ispMBRTK01]
   @c_MbolKey NVARCHAR(10),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT
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
           @c_AreaKey NVARCHAR(10), -- (ChewKP01)
           @c_Svalue NVARCHAR(10) --NJOW01

  SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1

   IF NOT EXISTS(SELECT 1 FROM MBOLDETAIL WITH (NOLOCK)
                  WHERE MbolKey = @c_MbolKey)
  BEGIN
     SELECT @n_continue = 3
     SELECT @n_err = 63501
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Orders being populated into MBOLDetail. (ispMBRTK01)"
      GOTO RETURN_SP
  END

   IF NOT EXISTS(SELECT 1 FROM LOADPLANLANEDETAIL WITH (NOLOCK)
                  WHERE MbolKey = @c_MbolKey)
  BEGIN
     SELECT @n_continue = 3
     SELECT @n_err = 63502
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Lanes/Doors being assigned for the MBOL. (ispMBRTK01)"
      GOTO RETURN_SP
  END

   IF NOT EXISTS(SELECT 1 FROM LOADPLANLANEDETAIL WITH (NOLOCK)
                 JOIN LOC (NOLOCK) ON LOADPLANLANEDETAIL.Loc = LOC.Loc
                 WHERE MbolKey = @c_MbolKey AND LOC.LocationCategory = 'STAGING')
  BEGIN
     SELECT @n_continue = 3
     SELECT @n_err = 63503
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Wrong Lanes/Doors being assigned. Only STAGING is allowed. (ispMBRTK01)"
      GOTO RETURN_SP
  END

   IF EXISTS(SELECT 1 FROM MBOLDETAIL WITH (NOLOCK)
                  JOIN PICKDETAIL WITH (NOLOCK) ON MBOLDETAIL.Orderkey = PICKDETAIL.Orderkey
                  --LEFT JOIN REFKEYLOOKUP WITH (NOLOCK) ON PICKDETAIL.Pickdetailkey = REFKEYLOOKUP.Pickdetailkey
                  LEFT JOIN PACKHEADER WITH (NOLOCK) ON PICKDETAIL.Pickslipno = PACKHEADER.Pickslipno
                  WHERE MBOLDETAIL.MbolKey = @c_MbolKey AND PACKHEADER.Pickslipno IS NULL)
  BEGIN
     SELECT @n_continue = 3
     SELECT @n_err = 63504
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Complete Pack being created for the MBOL. (ispMBRTK01)"
      GOTO RETURN_SP
  END
  
  SELECT @c_Storerkey = MIN(ORDERS.Storerkey)
  FROM MBOLDETAIL (NOLOCK)
  JOIN ORDERS (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey
  WHERE MBOLDETAIL.Mbolkey = @c_MbolKey

  --NJOW01
  SELECT @c_Svalue = Svalue 
  FROM STORERCONFIG (NOLOCK)
  WHERE Storerkey = @c_Storerkey
  AND Configkey = 'MASTERPACK'

  SELECT DISTINCT PD.PickSlipNo,  
      	 CASE WHEN ISNULL(PD.Refno,'') <> '' AND ISNULL(PD.Refno2,'') <> '' AND @c_Svalue = '1' THEN
	                        PD.Refno2 ELSE PD.LabelNo END AS LabelNo
  INTO #TMP_PACKDETAIL
  FROM MBOLDETAIL MD (NOLOCK)
  JOIN PICKDETAIL PICKD (NOLOCK) ON MD.Orderkey = PICKD.Orderkey
  JOIN REFKEYLOOKUP RF (NOLOCK) ON PICKD.Pickdetailkey = RF.Pickdetailkey
  JOIN PACKHEADER PH (NOLOCK) ON RF.Pickslipno = PH.Pickslipno
  JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
	WHERE MD.Mbolkey = @c_Mbolkey
 	
  BEGIN TRAN
  IF @n_continue = 1 OR @n_continue = 2
  BEGIN
     SELECT @c_Toloc = MIN(LOADPLANLANEDETAIL.Loc)
     FROM LOADPLANLANEDETAIL (NOLOCK)
     JOIN LOC (NOLOCK) ON LOADPLANLANEDETAIL.Loc = LOC.Loc  --NJOW02
     WHERE LOADPLANLANEDETAIL.MbolKey = @c_MbolKey
     AND LOC.LocationCategory = 'STAGING' --NJOW02

     DECLARE cur_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT DROPID.DROPID, DROPID.Droploc
         FROM MBOLDETAIL (NOLOCK)
         JOIN PICKDETAIL WITH (NOLOCK) ON MBOLDETAIL.Orderkey = PICKDETAIL.Orderkey
         JOIN REFKEYLOOKUP WITH (NOLOCK) ON PICKDETAIL.Pickdetailkey = REFKEYLOOKUP.Pickdetailkey
         JOIN PACKHEADER WITH (NOLOCK) ON REFKEYLOOKUP.Pickslipno = PACKHEADER.Pickslipno
         JOIN #TMP_PACKDETAIL PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)  --NJOW01
         JOIN DROPIDDETAIL WITH (NOLOCK) ON (PACKDETAIL.LabelNo = DROPIDDETAIL.Childid)
         JOIN DROPID WITH (NOLOCK) ON (DROPIDDETAIL.Dropid = DROPID.Dropid)
         JOIN LOC WITH (NOLOCK) ON (DROPID.Droploc = LOC.Loc)
         LEFT JOIN TASKDETAIL WITH (NOLOCK) ON (MBOLDETAIL.MBOLKEY = TASKDETAIL.Sourcekey AND TASKDETAIL.SourceType = 'ispMBRTK01'
                                           AND DROPID.Dropid = TASKDETAIL.FromId AND TASKDETAIL.TaskType ='NMV')
         WHERE MBOLDETAIL.Mbolkey = @c_Mbolkey
         AND TASKDETAIL.Taskdetailkey IS NULL
         AND LOC.LocationCategory='PACK&HOLD'
         AND DROPID.Status = '3' --(ung01)

         OPEN cur_TASK
         FETCH NEXT FROM cur_TASK INTO @c_DropId, @c_FromLoc

         WHILE @@FETCH_STATUS = 0
         BEGIN

          -- (ChewKP01)
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
             ,AreaKey -- (ChewKP01)
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
             ,'ispMBRTK01' --Sourcetype
             ,@c_mbolkey --Sourcekey
             ,'5' -- Priority
             ,'9' -- Sourcepriority
             ,'0' -- Status
             ,@c_FromLoc --Logical from loc
             ,@c_ToLoc --Logical to loc
             ,'FP' --pickmethod
             ,@c_AreaKey -- (ChewKP01)
            )

            SELECT @n_err = @@ERROR

          IF @n_err <> 0
          BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 63505
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert TASKDETAIL Failed. (ispMBRTK01)"
              GOTO RETURN_SP
          END

            FETCH NEXT FROM cur_TASK INTO @c_DropId, @c_FromLoc
         END
         CLOSE cur_TASK
         DEALLOCATE cur_TASK
   END
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
 execute nsp_logerror @n_err, @c_errmsg, 'ispMBRTK01'
 --RAISERROR @n_err @c_errmsg
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

GO