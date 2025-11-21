SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Trigger: ntrPOHeaderDelete                                           */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: When Delete PO Header Record                              */
/*                                                                      */
/* PVCS Version: 1.30                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 14-Jul-2011  KHLim02   1.1   GetRight for Delete log                 */
/* 18-Oct-2021  KSChin    1.2   add tracker to DEL_PO table             */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrPOHeaderDelete]
 ON [dbo].[PO]
 FOR DELETE
 AS
 BEGIN
 IF @@ROWCOUNT = 0
 BEGIN
 RETURN
 END
  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE @b_Success       int,       -- Populated by calls to stored procedures - was the proc successful?
 @n_err              int,       -- Error number returned by stored procedure or this trigger
 @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
 @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
 @n_starttcnt        int,       -- Holds the current transaction count
 @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
,@c_authority        NVARCHAR(1)  -- KHLim02
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRPOHD1.SQL> */     
 IF (select count(*) from DELETED) =
 (select count(*) from DELETED where DELETED.ArchiveCop = '9')
 BEGIN
 select @n_continue = 4
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 DELETE PODetail FROM PODetail, Deleted
 WHERE PODetail.POKey=Deleted.POKey
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 64501   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On Table PODETAIL Failed. (ntrPOHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 END

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
               ,@c_errmsg = 'ntrPOHeaderDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.PO_DELLOG ( POKey )
         SELECT POKey FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PO Failed. (ntrPOHeaderDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
--added by KS Chin
  IF @n_continue = 1 or @n_continue=2  
   BEGIN
   IF EXISTS(SELECT 1 FROM DEL_PO WITH (NOLOCK) 
               JOIN DELETED ON DELETED.POKey= DEL_PO.POKey )
      BEGIN
         DELETE  DEL_PO
         FROM   DEL_PO
         JOIN   DELETED ON DELETED.POKey = DEL_PO.POKey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62401   
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete DEL_PO Failed. (ntrPOHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END   
   INSERT INTO DEL_PO (POKey, ExternPOKey, POGroup, StorerKey, PODate, SellersReference, 
            BuyersReference, OtherReference, POType, SellerName, SellerAddress1, SellerAddress2, 
            SellerAddress3, SellerAddress4, SellerCity, SellerState, SellerZip, SellerPhone,
            SellerVat, BuyerName, BuyerAddress1, BuyerAddress2, BuyerAddress3,BuyerAddress4, BuyerCity,
            BuyerState, BuyerZip, BuyerPhone, BuyerVAT, OriginCountry, DestinationCountry,
            Vessel, VesselDate, PlaceOfLoading, PlaceOfDischarge, PlaceOfDelivery, IncoTerms, Pmtterm,
            TransMethod, TermsNote, Signatory, PlaceofIssue, OpenQty, Status, Notes, EffectiveDate,
            AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, ExternStatus, LoadingDate,
            ReasonCode,UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
            UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, xdockpokey,
            SellerCompany, SellerCountry, SellerContact1, SellerContact2, SellerPhone2, SellerEmail1,
            SellerEmail2, SellerFax1, SellerFax2)
      SELECT POKey, ExternPOKey, POGroup, StorerKey, PODate, SellersReference, 
            BuyersReference, OtherReference, POType, SellerName, SellerAddress1, SellerAddress2, 
            SellerAddress3, SellerAddress4, SellerCity, SellerState, SellerZip, SellerPhone,
            SellerVat, BuyerName, BuyerAddress1, BuyerAddress2, BuyerAddress3,BuyerAddress4, BuyerCity,
            BuyerState, BuyerZip, BuyerPhone, BuyerVAT, OriginCountry, DestinationCountry,
            Vessel, VesselDate, PlaceOfLoading, PlaceOfDischarge, PlaceOfDelivery, IncoTerms, Pmtterm,
            TransMethod, TermsNote, Signatory, PlaceofIssue, OpenQty, Status, Notes, EffectiveDate,
            getdate(), suser_sname(), EditDate, EditWho, TrafficCop, ArchiveCop, ExternStatus, LoadingDate,
            ReasonCode,UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
            UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, xdockpokey,
            SellerCompany, SellerCountry, SellerContact1, SellerContact2, SellerPhone2, SellerEmail1,
            SellerEmail2, SellerFax1, SellerFax2 FROM DELETED 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62401   
         SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Insert DEL_PO Failed. (ntrPOHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END -- Added End by KS Chin

      /* #INCLUDE <TRPOHD2.SQL> */
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
 EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrPOHeaderDelete"
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
 END


GO