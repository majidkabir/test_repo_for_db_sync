SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Trigger: ntrOrderHeaderDelete                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Order Header Delete Transaction                            */
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
/* Called By: When records delete                                       */
/*                                                                      */
/* PVCS Version: 1.13                                                   */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Purposes                                       */
/* 04-Apr-2008  Shong    Delete DEL_ORDERS When OrderKey exists and     */
/*                       Insert new records.                            */ 
/* 09-May-2008  Shong    Missing check error , @n_err = @@ERROR         */
/* 24-Nov-2008  James    Change insert portion of table DEL_Orders &    */
/*                       OrdersLog to reflect new table structure       */
/* 30-Mar-2010  TLTING   Remove OrderInfo                               */
/* 28-Apr-2011  KHLim01  Insert Delete log                              */
/* 14-Jul-2011  KHLim02  GetRight for Delete log                        */
/* 22-May-2012  TLTING02 Data integrity - insert dellog 4 status < '9'  */
/* 20-May-2015  MCTang   Enhance Generaic Trigger Interface (MC01)      */
/* 02-OCT-2015  NJOW01   354034 - call custom stored proc               */
/* 13-Feb-2018  CheeMun  INC0133268 - Insert into orders_dellog         */
/*                       status <> '9'                                  */
/* 15-Jan-2021  TLTING03 Add New Orders fields                          */
/* 27-Jul-2021  TLTING04 Add new ECOM_OAID                              */
/* 09-Aug-2021  TLTING05 Add new ECOM_Platform                          */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrOrderHeaderDelete]
ON [dbo].[ORDERS]
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

   DECLARE 
   @b_Success          int,       -- Populated by calls to stored procedures - was the proc successful?
   @n_err              int,       -- Error number returned by stored procedure or this trigger
   @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
   @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
   @n_starttcnt        int,       -- Holds the current transaction count
   @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
  ,@c_authority        NVARCHAR(1)  -- KHLim02
  ,@c_orderkey         NVARCHAR(10) -- MC01

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TROHD1.SQL> */

   IF (SELECT COUNT(*) FROM DELETED) = (SELECT COUNT(*) FROM DELETED WHERE DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END
   
   -- TLTING01
   IF EXISTS ( SELECT 1 FROM DELETED WHERE [STATUS] <> '9' ) --INC0133268
   BEGIN
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
                  ,@c_errmsg = 'ntrOrderHeaderDelete' + dbo.fnc_RTrim(@c_errmsg)
         END
         ELSE 
         IF @c_authority = '1'         --    End   (KHLim02)
         BEGIN
            INSERT INTO dbo.ORDERS_DELLOG ( OrderKey )
            SELECT OrderKey FROM DELETED
            WHERE [STATUS] < '9' 

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table ORDERS Failed. (ntrOrderHeaderDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
            END
         END
      END
      -- End (KHLim01) 
   END
   
   -- Added By SHONG 
   -- Date: 13-Feb-2004
   -- SOS#19801 
   -- Do not allow to delete Cancel Orders if StorerConfig = NotAllowDelCancOrd is Turn ON
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF EXISTS(SELECT 1 
                FROM  DELETED 
                JOIN  StorerConfig (NOLOCK) ON (DELETED.StorerKey = StorerConfig.StorerKey AND
                                                StorerConfig.ConfigKey = 'NotAllowDelCancOrd' AND
                                                StorerConfig.sValue = '1')
  WHERE (DELETED.SOStatus = 'CANC' OR DELETED.Status = 'CANC')
                )
      BEGIN
         SELECT @n_continue = 3 , @n_err = 62604
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Canceled Order(s) Not Allow to Delete. (ntrOrderHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   --NJOW01
   IF @n_continue=1 or @n_continue=2          
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d  
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'OrdersTrigger_SP')  
      BEGIN        	  
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
      	 SELECT * 
      	 INTO #INSERTED
      	 FROM INSERTED
            
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
   
      	 SELECT * 
      	 INTO #DELETED
      	 FROM DELETED
   
         EXECUTE dbo.isp_OrdersTrigger_Wrapper
                   'DELETE'  --@c_Action
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  
   
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrOrderHeaderDelete ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END   

   -- trigantic tracking of deleted order: wally 10.jul.03
   IF @n_continue <> 4
   BEGIN
      -- Added By SHONG on 2bd Apr 2008 
      -- Delete the previous OrderKey, otherwise will hit Unique Key Contraints 
      IF EXISTS(SELECT 1 FROM DEL_ORDERS WITH (NOLOCK) 
                JOIN DELETED ON DELETED.OrderKey = DEL_ORDERS.OrderKey )
      BEGIN
         DELETE DEL_ORDERS 
         FROM   DEL_ORDERS
         JOIN   DELETED ON DELETED.OrderKey = DEL_ORDERS.OrderKey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete DEL_ORDERS Failed. (ntrOrderHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END

      END   

      INSERT INTO DEL_ORDERS(OrderKey, StorerKey, ExternOrderKey, OrderDate, DeliveryDate, Priority, 
            ConsigneeKey, C_contact1, C_Contact2, C_Company, C_Address1, C_Address2, 
            C_Address3, C_Address4, C_City, C_State, C_Zip, C_Country, C_ISOCntryCode, 
            C_Phone1, C_Phone2, C_Fax1, C_Fax2, C_vat, BuyerPO, BillToKey, B_contact1, 
            B_Contact2, B_Company, B_Address1, B_Address2, B_Address3, B_Address4, B_City, 
            B_State, B_Zip, B_Country, B_ISOCntryCode, B_Phone1, B_Phone2, B_Fax1, B_Fax2, B_Vat, 
            IncoTerm, PmtTerm, OpenQty, Status, DischargePlace, DeliveryPlace, IntermodalVehicle, 
            CountryOfOrigin, CountryDestination, UpdateSource, Type, OrderGroup, Door, Route, Stop, 
            EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, 
            ContainerType, ContainerQty, BilledContainerQty, SOStatus, MBOLKey, InvoiceNo, InvoiceAmount, 
            Salesman, GrossWeight, Capacity, PrintFlag, LoadKey, Rdd, SequenceNo, Rds, 
            SectionKey, Facility, PrintDocDate, LabelPrice, POKey, ExternPOKey, XDockFlag, UserDefine01, 
            UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06, UserDefine07, UserDefine08, 
            UserDefine09, UserDefine10, Issued, DeliveryNote, PODCust, PODArrive, PODReject, PODUser, 
            xdockpokey, SpecialHandling, RoutingTool,MarkforKey, M_Contact1, M_Contact2, M_Company, M_Address1, 
            M_Address2, M_Address3, M_Address4, M_City, M_State, M_Zip, M_Country, M_ISOCntryCode, M_Phone1, 
            M_Phone2, M_Fax1, M_Fax2, M_vat, ShipperKey,
            DocType,TrackingNo,ECOM_PRESALE_FLAG,ECOM_SINGLE_Flag,CurrencyCode,RTNTrackingNo,BizUnit, ECOM_OAID,
            ECOM_Platform )
      SELECT OrderKey, StorerKey, ExternOrderKey, OrderDate, DeliveryDate, Priority, 
            ConsigneeKey, C_contact1, C_Contact2, C_Company, C_Address1, C_Address2, 
            C_Address3, C_Address4, C_City, C_State, C_Zip, C_Country, C_ISOCntryCode, 
            C_Phone1, C_Phone2, C_Fax1, C_Fax2, C_vat, BuyerPO, BillToKey, B_contact1, 
            B_Contact2, B_Company, B_Address1, B_Address2, B_Address3, B_Address4, B_City, 
            B_State, B_Zip, B_Country, B_ISOCntryCode, B_Phone1, B_Phone2, B_Fax1, B_Fax2, B_Vat, 
            IncoTerm, PmtTerm, OpenQty, Status, DischargePlace, DeliveryPlace, IntermodalVehicle, 
            CountryOfOrigin, CountryDestination, UpdateSource, Type, OrderGroup, Door, Route, Stop, 
            EffectiveDate, getdate(), suser_sname(), getdate(), suser_sname(), TrafficCop, ArchiveCop, 
            ContainerType, ContainerQty, BilledContainerQty, SOStatus, MBOLKey, InvoiceNo, InvoiceAmount, 
            Salesman, GrossWeight, Capacity, PrintFlag, LoadKey, Rdd, SequenceNo, Rds, 
            SectionKey, Facility, PrintDocDate, LabelPrice, POKey, ExternPOKey, XDockFlag, UserDefine01, 
            UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06, UserDefine07, UserDefine08, 
            UserDefine09, UserDefine10, Issued, DeliveryNote, PODCust, PODArrive, PODReject, PODUser, 
            xdockpokey, SpecialHandling, RoutingTool, MarkforKey, M_Contact1, M_Contact2, M_Company, M_Address1, 
            M_Address2, M_Address3, M_Address4, M_City, M_State, M_Zip, M_Country, M_ISOCntryCode, M_Phone1, 
            M_Phone2, M_Fax1, M_Fax2, M_vat, ShipperKey,
            DocType,TrackingNo,ECOM_PRESALE_FLAG,ECOM_SINGLE_Flag,CurrencyCode,RTNTrackingNo,BizUnit , ECOM_OAID,
            ECOM_Platform
            FROM DELETED 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Insert DEL_ORDERS Failed. (ntrOrderHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF @n_continue = 1 or @n_continue=2  
   BEGIN  
      -- Add by June 8.May.02 - To monitor Orders deletion 
      INSERT INTO ORDERSLOG(OrderKey, StorerKey, ExternOrderKey, OrderDate, DeliveryDate, Priority, 
         ConsigneeKey, C_contact1, C_Contact2, C_Company, C_Address1, C_Address2, C_Address3, 
         C_Address4, C_City, C_State, C_Zip, C_Country, C_ISOCntryCode, C_Phone1, C_Phone2, 
         C_Fax1, C_Fax2, C_vat, BuyerPO, BillToKey, B_contact1, B_Contact2, B_Company, B_Address1, 
         B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Country, B_ISOCntryCode, 
         B_Phone1, B_Phone2, B_Fax1, B_Fax2, B_Vat, IncoTerm, PmtTerm, OpenQty, Status, 
         DischargePlace, DeliveryPlace, IntermodalVehicle, CountryOfOrigin, CountryDestination, 
         UpdateSource, Type, OrderGroup, Door, Route, Stop, EffectiveDate, AddDate, AddWho, 
         EditDate, EditWho, TrafficCop, ArchiveCop, ContainerType, ContainerQty, BilledContainerQty, 
         SOStatus, MBOLKey, InvoiceNo, InvoiceAmount, Salesman, GrossWeight, Capacity, PrintFlag, 
         LoadKey, Rdd, SequenceNo, Rds, SectionKey, Facility, PrintDocDate, LabelPrice, POKey, 
         ExternPOKey, XDockFlag, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
         UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, Issued, DeliveryNote, 
         PODCust, PODArrive, PODReject, PODUser, xdockpokey, delDate, delWho, SpecialHandling, RoutingTool,
         MarkforKey, M_Contact1, M_Contact2, M_Company, M_Address1, M_Address2, M_Address3, M_Address4, 
         M_City, M_State, M_Zip, M_Country, M_ISOCntryCode, M_Phone1, M_Phone2, M_Fax1, M_Fax2, M_vat, ShipperKey,
         DocType,TrackingNo,ECOM_PRESALE_FLAG,ECOM_SINGLE_Flag,CurrencyCode,RTNTrackingNo,BizUnit , ECOM_OAID,
         ECOM_Platform )
      SELECT OrderKey, StorerKey, ExternOrderKey, OrderDate, DeliveryDate, Priority, 
         ConsigneeKey, C_contact1, C_Contact2, C_Company, C_Address1, C_Address2, C_Address3, 
         C_Address4, C_City, C_State, C_Zip, C_Country, C_ISOCntryCode, C_Phone1, C_Phone2, 
         C_Fax1, C_Fax2, C_vat, BuyerPO, BillToKey, B_contact1, B_Contact2, B_Company, B_Address1, 
         B_Address2, B_Address3, B_Address4, B_City, B_State, B_Zip, B_Country, B_ISOCntryCode, 
         B_Phone1, B_Phone2, B_Fax1, B_Fax2, B_Vat, IncoTerm, PmtTerm, OpenQty, Status, 
         DischargePlace, DeliveryPlace, IntermodalVehicle, CountryOfOrigin, CountryDestination, 
         UpdateSource, Type, OrderGroup, Door, Route, Stop, EffectiveDate, AddDate, AddWho, 
         EditDate, EditWho, TrafficCop, ArchiveCop, ContainerType, ContainerQty, BilledContainerQty, 
         SOStatus, MBOLKey, InvoiceNo, InvoiceAmount, Salesman, GrossWeight, Capacity, PrintFlag, 
         LoadKey, Rdd, SequenceNo, Rds, SectionKey, Facility, PrintDocDate, LabelPrice, POKey, 
         ExternPOKey, XDockFlag, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
         UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, Issued, DeliveryNote, 
         PODCust, PODArrive, PODReject, PODUser, xdockpokey, GETDATE(), sUSER_sNAME(), SpecialHandling, RoutingTool,
         MarkforKey, M_Contact1, M_Contact2, M_Company, M_Address1, M_Address2, M_Address3, M_Address4, 
         M_City, M_State, M_Zip, M_Country, M_ISOCntryCode, M_Phone1, M_Phone2, M_Fax1, M_Fax2, M_vat, ShipperKey,
         DocType,TrackingNo,ECOM_PRESALE_FLAG,ECOM_SINGLE_Flag,CurrencyCode,RTNTrackingNo,BizUnit  , ECOM_OAID,
         ECOM_Platform
      FROM DELETED

   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DELETE OrderDetail FROM OrderDetail, Deleted
      WHERE OrderDetail.OrderKey=Deleted.OrderKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On ORDERDETAIL Failed. (ntrOrderHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DELETE WaveDetail FROM Deleted
      WHERE WaveDetail.OrderKey=Deleted.OrderKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62402
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On WAVEDETAIL Failed. (ntrOrderHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   /*---------------------------------------------Customistation Start -----------------------------------------------------------*/
   /*  Date : 18/9/99
     FBR : 005
     Author : HPH
     Purpose
     Parameters :
   -------------------------------------------------------------------------------------------------------------------------------*/
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DELETE MBOLDetail 
      FROM   Deleted
      WHERE  MBOLDetail.OrderKey = Deleted.OrderKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62403
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On MBOLDETAIL Failed. (ntrOrderHeaderDelete)"
      END
   END
   /* -------------------------------------------- Customisation of FBR999 ends --------------------------------------------*/
   
   /* Added By SHONG - to track who delete this order */
--    IF @n_continue = 1 or @n_continue = 2
--    BEGIN
--    INSERT INTO DEL_ORDERS
--          SELECT * FROM DELETED
--    
--    UPDATE DEL_ORDERS
--       SET AddWho = User_Name(),
--           EditWho = User_Name(),
--           AddDate = GetDate(),
--           EditDate = GetDate()
--    FROM DEL_ORDERS, DELETED
--    WHERE DEL_ORDERS.OrderKey = DELETED.OrderKey
--    
--    END
   -- End of customize - shong
   -- Added By SHONG - 25th-JUL-2002
   -- This should be in Base
IF @n_continue = 1 or @n_continue = 2
BEGIN
   DELETE LOADPLANDETAIL
   FROM Deleted
   WHERE LOADPLANDETAIL.OrderKey = Deleted.OrderKey
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 62404
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On LOADPLANDETAIL Failed. (ntrOrderHeaderDelete)"
   END
END
-- Remove Pick Ticket No
IF @n_continue = 1 or @n_continue = 2
BEGIN
   DELETE PICKHEADER
   FROM Deleted
   WHERE PICKHEADER.OrderKey=Deleted.OrderKey
   AND   ZONE = '8'
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 62405
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On LOADPLANDETAIL Failed. (ntrOrderHeaderDelete)"
   END
END

-- Remove Order Info
IF @n_continue = 1 or @n_continue = 2
BEGIN
   DELETE OrderInfo
   FROM Deleted
   WHERE OrderInfo.OrderKey=Deleted.OrderKey

   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 62409
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On OrderInfo Failed. (ntrOrderHeaderDelete)"
   END
END


   /********************************************************/  
   /* Interface Trigger Points Calling Process - (Start)   */  
   /********************************************************/  
   --MC01 - S
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN 
      DECLARE Cur_Itf_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT  DISTINCT INS.ORDERKEY 
      FROM    DELETED INS 
      JOIN    ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey  
      WHERE   ITC.SourceTable = 'ORDERS'  
      AND     ITC.sValue      = '1' 
      UNION                                                                                           
      SELECT DISTINCT IND.ORDERKEY                                                                    
      FROM   DELETED IND                                                                             
      JOIN   ITFTriggerConfig ITC WITH (NOLOCK)                                                       
      ON     ITC.StorerKey   = 'ALL'                                                                  
      JOIN   StorerConfig STC WITH (NOLOCK)                                                           
      ON     STC.StorerKey   = IND.StorerKey AND STC.ConfigKey = ITC.ConfigKey AND STC.SValue = '1'   
      WHERE  ITC.SourceTable = 'ORDERS'                                                               
      AND    ITC.sValue      = '1'                                                                    

      OPEN Cur_Itf_TriggerPoints
      FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_orderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         EXECUTE dbo.isp_ITF_ntrOrderHeader   
                  @c_TriggerName    = 'ntrOrderHeaderDelete'
                , @c_SourceTable    = 'ORDERS'  
                , @c_OrderKey       = @c_orderkey  
                , @c_ColumnsUpdated = ''        
                , @b_Success        = @b_Success OUTPUT  
                , @n_err            = @n_err    OUTPUT  
                , @c_errmsg         = @c_errmsg  OUTPUT  

         FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_orderkey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_Itf_TriggerPoints
      DEALLOCATE Cur_Itf_TriggerPoints

   END
   --MC01 - E
   /********************************************************/  
   /* Interface Trigger Points Calling Process - (End)     */  
   /********************************************************/  

   /* #INCLUDE <TROHD2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrOrderHeaderDelete"
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