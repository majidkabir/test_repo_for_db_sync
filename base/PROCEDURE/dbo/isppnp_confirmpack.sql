SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPnp_ConfirmPack                                 */  
/* Creation Date: 05-Aug-2002                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: NIKE Taiwan Scan & Pack, Pack Confirmation                  */  
/*                                                                      */  
/* Called By: PowerBuilder Program                                      */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author Ver Purposes                                     */  
/* 11-Apr-2007  Shong  1.0 Change the Pick Confirmation using Stored    */  
/*                         Instead of fire the PickingInfo trigger.     */   
/* 25-APR-2012  YTWan  1.1 Update Packheader First Then Pick Confirm    */  
/*                         (Wan01)                                      */  
/* 05-JUL-2012  YTWan  1.2 Fixed. Inventory & Picking update from       */  
/*                         isp_ScanOutPickSlip not via                  */   
/*                         ntrPickingInfo. (Wan02)                      */  
/* 08-APR-2013  Shong  1.3 Performance Tuning                           */
/* 25-SEP-2013  NJOW01 1.4 290121-Allow update label no to pickdetail   */
/*                         drop id                                      */
/************************************************************************/  
CREATE PROC [dbo].[ispPnp_ConfirmPack]  
         @c_PickSlipNo     NVARCHAR(20),  
         @b_Success        INT       OUTPUT,  
         @n_err            INT       OUTPUT,  
         @c_errmsg         NVARCHAR(255) OUTPUT  
AS  
SET NOCOUNT ON   
SET QUOTED_IDENTIFIER OFF   
SET CONCAT_NULL_YIELDS_NULL OFF  
  
DECLARE @n_count INT /* next key */  
DECLARE @n_ncnt INT  
DECLARE @n_starttcnt INT /* Holds the current transaction count */  
DECLARE @n_continue INT /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */  
DECLARE @n_cnt INT /* Variable to record if @@ROWCOUNT=0 after UPDATE */  
SELECT @n_starttcnt = @@TRANCOUNT
      ,@n_continue = 1
      ,@b_success = 0
      ,@n_err = 0
      ,@c_errmsg = '' 


BEGIN TRANSACTION   
  
IF NOT EXISTS(
       SELECT 1
       FROM   PICKHEADER(NOLOCK)
       WHERE  PICKHEADERKEY = @c_PickSlipNo
   )
BEGIN
    SELECT @n_continue = 3   
    SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
          ,@n_err = 62000 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
    SELECT @c_errmsg = 'Invalid Pick Slip No. (ispPnp_ConfirmPack)'
END  
  
  
--(Wan02)  - START -- When ScanOutDate Null, it will trigger ntrPickingInfoUpdate (update picking and inventory) at ntrPackHeaderUpdate  

IF @n_continue = 1 OR @n_continue = 2
BEGIN
    UPDATE PickingInfo WITH (ROWLOCK)
    SET    ScanOutDate = DateAdd(minute, 1, GETDATE()) -- Plus 1 minutes so that that will not trigger ispPickConfirmCheck (Shong01)  
          ,TrafficCop = 'U'
    WHERE  PickSlipNo = @c_pickslipno  
    
    SET @n_err = @@ERROR  
    IF @n_err <> 0
    BEGIN
        SET @n_continue = 3    
        SET @n_err = 61901  
        SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,ISNULL(dbo.fnc_RTrim(@n_err) ,0)) 
            + ': Update Failed On Table PICKINGINFO. (isp_ScanOutPickSlip)' + 
            ' ( ' 
            + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) ,'') 
            + ' ) '
    END
END  
--(Wan02)  - END  
--(Wan01)  - START  
IF @n_continue = 1 OR @n_continue = 2 
BEGIN
    UPDATE PACKHEADER WITH (ROWLOCK)
    SET    STATUS = '9',
           EditDate = GETDATE(),
           EditWho = sUser_sName()
    WHERE  PickSlipNo = @c_PickSlipNo
    AND    STATUS < '9'
    
    IF @@ERROR <> 0
    BEGIN
        SELECT @n_continue = 3   
        SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
              ,@n_err = 61902 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) + 
               ': Update PACKHEADER Failed. (ispPnp_ConfirmPack)'
    END
END  
--(Wan01)  - END  
  
IF @n_continue = 1 OR @n_continue = 2
BEGIN
    -- Change by Shong on 11th Apr 2007   
    EXEC isp_ScanOutPickSlip @c_PickSlipNo
        ,@n_err OUTPUT
        ,@c_errmsg OUTPUT
    
    IF @n_err <> 0
    BEGIN
        SELECT @n_continue = 3   
        SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
              ,@n_err = 61903 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) + 
               ': Update PickingInfo Failed. (ispPnp_ConfirmPack)'
    END
END -- IF @n_continue = 1 OR @n_continue = 2  

--NJOW01
IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF EXISTS(SELECT 1 FROM PACKHEADER PH (NOLOCK) 
             JOIN STORERCONFIG SC (NOLOCK) ON PH.Storerkey = SC.Storerkey
             WHERE SC.Configkey = 'AssignPackLabelToOrdCfg'
             AND SC.Svalue = '1'
             AND PH.Pickslipno = @c_PickSlipNo)
   BEGIN    
       EXEC isp_AssignPackLabelToOrderByLoad
	     @c_PickSlipNo, 
	     @b_success OUTPUT, 
	     @n_err OUTPUT,
	     @c_errmsg OUTPUT 
	
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3   
       END
   END
END          
           
IF @n_continue = 3 -- Error Occured - Process And Return
BEGIN
    SELECT @b_success = 0 
    ROLLBACK TRAN 
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPnp_ConfirmPack' 
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
    RETURN
END
ELSE
BEGIN
    SELECT @b_success = 1  
    WHILE @@TRANCOUNT > @n_starttcnt
    BEGIN
        COMMIT TRAN
    END 
    RETURN
END -- procedure  

GO