SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Trigger: ntrPODetailDelete                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Update/Delete other transactions while PODetail line is    */
/*           to be deleted.                                             */
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
/* Called By: When records deleted                                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 01-Jun-2005  YokeBeen   For NSC PO/UCC Inbound - (YokeBeen01)        */
/*                         Purge the records from the UCC table as the  */
/*                         podetail lines being purged.                 */
/* 16-Feb-2007  YokeBeen   For WMS-E1 Inbound - (YokeBeen02)            */
/*                         Having check on the PODetail.QtyReceived in  */
/*                         order to proceed with the valid deletion of  */
/*                         PODetail lines for E1 Storers. - (SOS#66639) */
/* 28-Apr-2011  KHLim01    Insert Delete log                            */
/* 14-Jul-2011  KHLim02    GetRight for Delete log                      */
/* 27-Jul-2017  TLTING   1.1  SET Option, missing nolock                */
/* 18-Oct-2021  KSChin   1.2  add tracker to DEL_PODetail table         */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrPODetailDelete]  
ON [dbo].[PODETAIL]  
FOR DELETE  
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

	DECLARE @b_debug int  
	SELECT @b_debug = 0  

	IF @b_debug = 1  
	BEGIN  
		SELECT "DELETED ", POKey, POLineNumber, StorerKey, Sku FROM DELETED  
	END  

	DECLARE @b_Success      int,       -- Populated by calls to stored procedures - was the proc successful?  
			@n_err            int,       -- Error number returned by stored procedure or this trigger  
			@c_errmsg         NVARCHAR(250), -- Error message returned by stored procedure or this trigger  
			@n_continue       int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing  
			@n_starttcnt      int,       -- Holds the current transaction count  
			@n_cnt            int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.  
        ,@c_authority      NVARCHAR(1)  -- KHLim02

	SELECT @n_continue	= 1, 
			 @n_starttcnt	= @@TRANCOUNT,  
			 @b_Success		= 0,
			 @n_err			= 0,
			 @c_errmsg		= '',
			 @n_cnt			= 0

	IF (SELECT COUNT(*) FROM DELETED) = (SELECT COUNT(*) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
	BEGIN  
		SELECT @n_continue = 4  
	END  

	/* #INCLUDE <TRPODD1.SQL> */       
	IF @n_continue = 1 OR @n_continue = 2  
	BEGIN  
      -- (YokeBeen02) - Start
		IF EXISTS (SELECT 1 FROM DELETED JOIN STORERCONFIG WITH (NOLOCK) ON (DELETED.Storerkey = STORERCONFIG.Storerkey) 
                  WHERE STORERCONFIG.ConfigKey = 'OWITF' AND STORERCONFIG.sValue = '1' 
                    AND (DELETED.QtyReceived > 0 OR DELETED.QtyReceived = 0))  
		BEGIN  
       UPDATE PO  
          SET Status = '9', 
              ExternStatus = 'CANC', 
              TrafficCop = NULL 
         FROM DELETED 
         JOIN PO WITH (NOLOCK) ON (DELETED.POKey = PO.POKey) 
         JOIN STORERCONFIG WITH (NOLOCK) ON (PO.Storerkey = STORERCONFIG.Storerkey AND STORERCONFIG.ConfigKey = 'OWITF' 
                                   AND STORERCONFIG.sValue = '1') 
        WHERE NOT EXISTS (SELECT 1 FROM PODETAIL WITH (NOLOCK) WHERE PODETAIL.POKey = DELETED.POKey 
                                                            AND PO.POKey = DELETED.POKey) 
      END 
      -- (YokeBeen02) - End 
      ELSE IF EXISTS (SELECT 1 FROM DELETED WHERE DELETED.QtyReceived > 0)  
      BEGIN 
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 64801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Trigger On Table PODETAIL Failed - QtyReceived must be zero. (ntrPODetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
		END  
	END  

	IF @n_continue = 1 OR @n_continue = 2  
	BEGIN  
		DELETE CASEMANIFEST  
		  FROM CASEMANIFEST, DELETED  
		 WHERE CASEMANIFEST.StorerKey = DELETED.StorerKey  
			AND CASEMANIFEST.Sku = DELETED.Sku  
			AND CASEMANIFEST.ExpectedPOKey = DELETED.POKey  

		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  

		IF @n_err <> 0  
		BEGIN  
			SELECT @n_continue = 3  
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 64203   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
			SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Trigger On Table CASEMANIFEST Failed - QtyReceived must be zero. (ntrPODetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
		END  
		ELSE IF @b_debug = 1  
		BEGIN  
			SELECT @n_cnt  

			SELECT StorerKey, Sku, ExpectedPOKey  
			  FROM CASEMANIFEST  WITH (NOLOCK)

			SELECT StorerKey, Sku, POKey  
			  FROM DELETED  
		END  
	END  

	-- (YokeBeen01) - Start
	IF @n_continue = 1 OR @n_continue = 2  
	BEGIN  
		IF EXISTS ( SELECT 1 FROM UCC WITH (NOLOCK) JOIN DELETED ON (UCC.Storerkey = DELETED.Storerkey 
							AND UCC.SourceKey = (CONVERT(CHAR(10),DELETED.POKey) + CONVERT(CHAR(5),DELETED.POLineNumber))) 
						 WHERE UCC.SourceType = 'PO' )
		BEGIN
			DELETE UCC  
			  FROM UCC WITH (NOLOCK) 
			  JOIN DELETED ON (UCC.Storerkey = DELETED.Storerkey 
								AND UCC.SourceKey = (CONVERT(CHAR(10),DELETED.POKey) + CONVERT(CHAR(5),DELETED.POLineNumber))) 
			 WHERE UCC.SourceType = 'PO' 

			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  

			IF @n_err <> 0  
			BEGIN  
				SELECT @n_continue = 3  
				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 64204   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
				SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Delete Trigger On Table UCC Failed. (ntrPODetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
			END  
			ELSE IF @b_debug = 1  
			BEGIN  
				SELECT @n_cnt  

				SELECT StorerKey, Sku, SourceKey  
				  FROM UCC  WITH (NOLOCK)

				SELECT StorerKey, Sku, POKey, POLineNumber  
				  FROM DELETED  
			END  
		END -- If record exists
	END  
	-- (YokeBeen01) - End

	IF @n_continue = 1 OR @n_continue=2  
	BEGIN  
		DECLARE @n_deletedcount int  
		SELECT @n_deletedcount = (SELECT count(*) FROM deleted)  

		IF @n_deletedcount = 1  
		BEGIN  
			UPDATE PO  
				SET OpenQty = PO.OpenQty - (DELETED.QtyOrdered - DELETED.QtyReceived)  
			  FROM PO, DELETED  
			 WHERE PO.POKey = DELETED.POKey  
		END  
		ELSE  
		BEGIN  
			UPDATE PO 
				SET PO.OpenQty = (PO.Openqty -  
					(SELECT SUM(DELETED.QtyOrdered - DELETED.QtyReceived) FROM DELETED WHERE DELETED.POKey = PO.POKey))  
			  FROM PO,DELETED  
			 WHERE PO.POKey IN (SELECT DISTINCT POKey FROM DELETED)  
				AND PO.POKey = DELETED.POKey  
		END  

		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  

		IF @n_err <> 0  
		BEGIN  
			SELECT @n_continue = 3  
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64803   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
			SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Insert failed on table PO. (ntrPODetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
		END  
	END  

   -- Start (KHLim01) 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrPODetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.PODETAIL_DELLOG ( POKey, POLineNumber )
         SELECT POKey, POLineNumber FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PODETAIL Failed. (ntrPODetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01) 
   --added by KS Chin
  IF @n_continue = 1 or @n_continue=2  
   BEGIN
   IF EXISTS(SELECT 1 FROM DEL_PODETAIL WITH (NOLOCK) 
               JOIN DELETED ON DELETED.POKey= DEL_PODETAIL.POKey AND DELETED.POLineNumber=DEL_PODETAIL.POLineNumber )
      BEGIN
         DELETE  DEL_PODETAIL
         FROM   DEL_PODETAIL
         JOIN   DELETED ON DELETED.POKey = DEL_PODETAIL.POKey AND DELETED.POLineNumber=DEL_PODETAIL.POLineNumber
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62401   
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete DEL_PODetail Failed. (ntrPODetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END   
   INSERT INTO DEL_PODETAIL (POKey, POLineNumber, StorerKey, PODetailKey, ExternPOKey, ExternLineNo,
               MarksContainer, Sku, SKUDescription, ManufacturerSku, RetailSku, AltSku,
               QtyOrdered, QtyAdjusted, QtyReceived, PackKey, UnitPrice, UOM, Notes,
               EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop,
               POLineStatus, Facility, shortcode, Best_bf_Date, Lottable01, Lottable02,
               Lottable03, Lottable04, Lottable05, UserDefine01, UserDefine02, UserDefine03, 
               UserDefine04, UserDefine05, UserDefine06, UserDefine07, UserDefine08, 
               UserDefine09, UserDefine10, ToId, Lottable06, Lottable07,Lottable08, Lottable09, Lottable10,
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, Channel)
      SELECT 	POKey,POLineNumber,StorerKey,PODetailKey,ExternPOKey,ExternLineNo,
             	MarksContainer,Sku,SKUDescription,ManufacturerSku,RetailSku,AltSku,
             	QtyOrdered,QtyAdjusted,QtyReceived,PackKey,UnitPrice,UOM,Notes,
             	EffectiveDate,  getdate(), suser_sname(), EditDate,EditWho,TrafficCop,ArchiveCop,
             	POLineStatus,Facility,shortcode,Best_bf_Date,Lottable01,Lottable02,
             	Lottable03,Lottable04,Lottable05,UserDefine01,UserDefine02, UserDefine03, 
             	UserDefine04, UserDefine05, UserDefine06, UserDefine07, UserDefine08, 
	     	UserDefine09, UserDefine10,ToId, Lottable06,Lottable07,Lottable08,Lottable09,Lottable10, 
		Lottable11, Lottable12,Lottable13,Lottable14,Lottable15,Channel FROM DELETED 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62401   
         SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Insert DEL_PODETAIL Failed. (ntrPODetailDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END -- Added End by KS Chin
	/* #INCLUDE <TRPODD2.SQL> */  
	IF @n_continue=3  -- Error Occured - Process And Return  
	BEGIN  
		IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt  
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

		EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrPODetailadd"  
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
		RETURN  
	END  
	ELSE  
	BEGIN  
		WHILE @@TRANCOUNT > @n_starttcnt  
		BEGIN  
			COMMIT TRAN  
		END  
		RETURN  
	END  
END  -- Trigger End

GO