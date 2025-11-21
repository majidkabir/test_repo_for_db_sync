SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: ntrCCDetailUpdate                                           */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  Adjustment Header Update Transaction                       */  
/*                                                                      */  
/* Input Parameters:                                                    */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Return Status:                                                       */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: When update records                                       */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 08-July-2005  Vicky    Add STKTAKELOG as Configkey for Interface     */  
/* 10-Nov-2005  Shong     Performance Tuning (SHONG_20051110)           */  
/* 02-Mar-2009  TLTING    SOS130316 update SKU.CycleCountDate tlting01  */  
/* 23 May 2012  TLTING02  DM integrity - add update editdate B4         */
/*                        TrafficCop for status < '9'                   */ 
/* 28-Oct-2013  TLTING    Review Editdate column update                 */
/* 21-Apr-2017  Ung       Fix recompile                                 */
/************************************************************************/  
  
CREATE TRIGGER [dbo].[ntrCCDetailUpdate] ON [dbo].[CCDetail]   
FOR UPDATE  
AS  
BEGIN  
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END     
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue int  
         , @b_success  int       -- Populated by calls to stored procedures - was the proc successful?  
     , @n_err      int       -- Error number returned by stored procedure or this trigger    
     , @c_errmsg   NVARCHAR(250) -- Error message returned by stored procedure or this trigger   
  
 SELECT @n_continue = 1  

 IF UPDATE(ArchiveCop)  
 BEGIN  
    SELECT @n_continue = 4 /* No error but skip the update */  
 END   
  
 -- tlting02
 IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
               Where INSERTED.CCDETAILKEY = DELETED.CCDETAILKEY
               AND ( INSERTED.[Status] < '9' OR DELETED.[Status] < '9' ) ) 
       AND ( @n_continue = 1 or @n_continue = 2 )
       AND NOT UPDATE(EditDate)
 BEGIN
 	 UPDATE CCDETAIL with (ROWLOCK)
 	 SET EditDate = GETDATE(), EditWho = Suser_Sname(),
        TrafficCop = NULL
	 FROM CCDETAIL ,	INSERTED, DELETED 
 	 WHERE CCDETAIL.CCDETAILKEY = INSERTED.CCDETAILKEY
 	 AND   INSERTED.CCDETAILKEY = DELETED.CCDETAILKEY
    AND   ( INSERTED.[Status] < '9' OR DELETED.[Status] < '9' )

 END
  
 IF UPDATE(TrafficCop)  
 BEGIN  
    SELECT @n_continue = 4 /* No error but skip the update */  
 END  
   
   -- Added By Vicky 08 July 2005 - STKTAKELOG- Start  
 IF @n_continue = 1 or @n_continue = 2   
 BEGIN  
        DECLARE  @c_CCKey            NVARCHAR(10)  
             , @c_Storerkey        NVARCHAR(20)  
            , @c_finalizecnt3flag NVARCHAR(1)  
               , @c_finalizeflag     NVARCHAR(1)  
               , @c_STKTAKELOG       NVARCHAR(1)  
               , @c_sku              NVARCHAR(20)    -- tlting01  
     
         SELECT @c_STKTAKELOG = '0'  
   
       SELECT TOP 1 
          @c_CCKey = INSERTED.CCKey,  
          @c_Storerkey = INSERTED.Storerkey,  
          @c_sku       = INSERTED.Sku,    -- tlting01  
          @c_finalizecnt3flag = CCDETAIL.FinalizeFlag_Cnt3,  
          @c_finalizeflag = CCDETAIL.FinalizeFlag  
       FROM  CCDETAIL CCDETAIL (NOLOCK), INSERTED,  DELETED  
     WHERE CCDETAIL.CCKey = INSERTED.CCKey  
     AND   INSERTED.CCKey = DELETED.CCKey  
  
       IF @c_finalizecnt3flag = 'Y'  
       BEGIN  
         EXECUTE nspGetRight  
                   NULL,       -- facility  
                 @c_Storerkey, -- Storerkey  
                 NULL,   -- Sku  
                 'STKTAKELOG', -- Configkey  
                   @b_success     OUTPUT,  
                   @c_STKTAKELOG  OUTPUT,  
                   @n_err         OUTPUT,  
               @c_errmsg      OUTPUT  
  
          IF @b_success <> 1  
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @c_errmsg = 'ntrCCDetailUpdate' + dbo.fnc_RTrim(@c_errmsg)  
          END  
          ELSE IF @c_STKTAKELOG = '1'  
          BEGIN  
              EXEC ispGenTransmitLog3 'STKTAKELOG', @c_CCKey, '', @c_Storerkey, ''   
                 , @b_success OUTPUT  
                 , @n_err OUTPUT  
                 , @c_errmsg OUTPUT  
  
             IF @b_success <> 1  
              BEGIN  
                  SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63811   -- should be set to the sql errmessage but i don't know how to do so.  
               SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err) + ': Unable To Obtain LogKey. (ntrCCDetailUpdate)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
              END  
         END -- @c_STKTAKELOG = '1'  
           
      END -- @c_FinalizedFlag = 'Y'  
        
       -- tlting01 start  
--       IF EXISTS ( SELECT 1  
--                   FROM  CCDETAIL CCDETAIL (NOLOCK), INSERTED,  DELETED  
--                 WHERE CCDETAIL.CCDETAILKey = INSERTED.CCDETAILKey  
--                 AND   INSERTED.CCDETAILKey = DELETED.CCDETAILKey  
--                 AND   ( ( INSERTED.FinalizeFlag <> DELETED.FinalizeFlag AND   INSERTED.FinalizeFlag = 'Y' )  
--                 OR   ( INSERTED.FinalizeFlag_Cnt2 <> DELETED.FinalizeFlag_Cnt2 AND   INSERTED.FinalizeFlag_Cnt2 = 'Y' )  
--                 OR   ( INSERTED.FinalizeFlag_Cnt3 <> DELETED.FinalizeFlag_Cnt3 AND   INSERTED.FinalizeFlag_Cnt3 = 'Y' )   ))  
         IF @n_continue = 1 or @n_continue = 2   
         BEGIN  
            DECLARE CUR_CCDUPDATE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
            SELECT DISTINCT CCDETAIL.sku   
          FROM  CCDETAIL CCDETAIL WITH (NOLOCK), INSERTED,  DELETED  
        WHERE CCDETAIL.CCDETAILKey = INSERTED.CCDETAILKey  
           AND   INSERTED.CCDETAILKey = DELETED.CCDETAILKey  
           AND   ( ( INSERTED.FinalizeFlag <> DELETED.FinalizeFlag AND   INSERTED.FinalizeFlag = 'Y' )  
              OR   ( INSERTED.FinalizeFlag_Cnt2 <> DELETED.FinalizeFlag_Cnt2 AND   INSERTED.FinalizeFlag_Cnt2 = 'Y' )  
              OR   ( INSERTED.FinalizeFlag_Cnt3 <> DELETED.FinalizeFlag_Cnt3 AND   INSERTED.FinalizeFlag_Cnt3 = 'Y' )   )  
            OPEN CUR_CCDUPDATE  
            FETCH NEXT FROM CUR_CCDUPDATE INTO @c_sku  
            WHILE @@FETCH_STATUS <> -1  
            BEGIN  
               UPDATE SKU with (RowLock)  
               SET LastCycleCount = GETDATE(),
                  EditDate = GETDATE(),   --tlting
                  EditWho = SUSER_SNAME()  
               WHERE SKU.Storerkey = @c_Storerkey  
                 AND SKU.Sku = @c_sku  
  
               FETCH NEXT FROM CUR_CCDUPDATE INTO @c_sku  
            END  
            CLOSE CUR_CCDUPDATE  
            DEALLOCATE CUR_CCDUPDATE  
       END   
       --tlting01 end  
           
    END -- Continue = 1 -- End STKTAKELOG  
  
END  

GO