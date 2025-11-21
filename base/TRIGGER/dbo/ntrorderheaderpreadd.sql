SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Trigger: ntrOrderHeaderPreAdd                                               */
/* Creation Date: 13-Aug-2020                                                  */
/* Copyright: :LFL                                                             */
/* Written by: SHONG                                                           */
/*                                                                             */
/* Purpose:   OrderHeader Pre Add Trigger                                      */
/*                                                                             */
/* Usage:                                                                      */
/*                                                                             */
/* Called By: Before records add into OrderHeader                              */
/*                                                                             */
/* PVCS Version: 1.4                                                           */
/*                                                                             */
/* Version: 5.4                                                                */
/*                                                                             */
/* Data Modifications:                                                         */
/* Date         Author     Ver  Purposes                                       */
/* 13-Aug-2020  Shong      1.0  Split Pre/Post Insert trigger                  */
/* 24-Sep-2020  SWT01      1.1  OpenQty Alway Default to ZERO when Insert      */ 
/* 15-Jan-2020  TLTING01   1.2  extend length                                  */  
/* 27-Jul-2021  TLTING01   1.3  Add new column  ECom_OAID                      */  
/* 09-Aug-2021  TLTING02   1.4  Add new column ECOM_Platform                   */  
/* 09-Aug-2021  TLTING03   1.5  extend length  UserDefine04                    */  
/* 20-Jun-2024  kelvinong  1.6  WMS-25648 extend length ECOM_OAID (kocy01)     */
/* 17-Aug-2024  PPA371     1.7 New column CancelReasonCode added               */
/*******************************************************************************/
CREATE   TRIGGER [dbo].[ntrOrderHeaderPreAdd]
   ON  [dbo].[ORDERS]
INSTEAD OF INSERT 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success                 INT -- Populated by calls to stored procedures - was the proc successful?
          ,@n_err                     INT -- Error number returned by stored procedure or this trigger
          ,@n_err2                    INT -- For Additional Error Detection
          ,@c_errmsg                  NVARCHAR(250) -- Error message returned by stored procedure or this trigger
          ,@n_continue                INT
          ,@n_starttcnt               INT -- Holds the current transaction count
          ,@c_preprocess              NVARCHAR(250) -- preprocess
          ,@c_pstprocess              NVARCHAR(250) -- post process
          ,@n_cnt                     INT
          ,@c_Authority_soaddlog      NVARCHAR(1) -- (MC01)
          ,@c_Authority_wscrsoadd     NVARCHAR(1) -- (KT01)
          ,@c_ECOM_Orders             CHAR(1)='N'
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
         
   DECLARE @n_ECOM_Orders            INT=0
          ,@n_TotalOrders            INT=0
          ,@c_TriganticLogkey        NVARCHAR(10)
          ,@c_Facility               NVARCHAR(5)=''
          ,@c_StorerKey              NVARCHAR(15)
          ,@c_Authority_AUOI         NVARCHAR(1)= '0'
          ,@c_Authority_auri         NVARCHAR(1)= '0'
          ,@c_OrdStatus              NVARCHAR(1)=''
          ,@c_OrderKey               NVARCHAR(10)=''  
          ,@c_Authority_tms          NVARCHAR(1)= '0'
          ,@n_TMSFleetWise           INT
          ,@c_ConsigneeKey           NVARCHAR(15)=''
          ,@c_OrderType              NVARCHAR(10)=''  
          ,@c_UserDefine08           NVARCHAR(10)=''  
          ,@c_KitDSCPick             NVARCHAR(10)=''  
          ,@c_Authority_OrderI       NCHAR(1)= '0'
          ,@c_Route                  NVARCHAR(10)=''  
          ,@c_NIKEREGITF             NVARCHAR(1)= '0'
          ,@c_Authority_xdroute      NVARCHAR(1)= '0'      
          ,@c_Authority_DefaultRoutingTool NVARCHAR(1) = '0'
          ,@c_Tablename              NVARCHAR(30)=''
          ,@c_Authority_SOITF        NVARCHAR(1)= '0'
          ,@c_Authority_priority     NVARCHAR(1)= '0'          
               


   -- ECOM Order should ne light update, need to reduce updating for non-ecom order requirement            
   SELECT @n_ECOM_Orders = SUM(CASE WHEN DocType = 'E' THEN 1 ELSE 0 END),
          @n_TotalOrders = SUM(1)
   FROM INSERTED 

   IF @n_ECOM_Orders = @n_TotalOrders
      SET @c_ECOM_Orders = 'Y'
   ELSE 
   	SET @c_ECOM_Orders = 'N'
      
   /* #INCLUDE <TROHA1.SQL> */

   /* #INCLUDE <TROHA2.SQL> */

   SET @c_UserDefine08 = 'N'              -- (Wan01)
   SET @c_KitDSCPick   = ''               -- (Wan01)

            
   DECLARE @t_ORDERS AS TABLE (
	[OrderKey] [nvarchar](10) NOT NULL,
	[StorerKey] [nvarchar](15) NOT NULL,
	[ExternOrderKey] [nvarchar](50) NOT NULL,
	[Priority] [nvarchar](10) NOT NULL,
	[ConsigneeKey] [nvarchar](15) NOT NULL,
	[C_contact1] [nvarchar](100) NULL,
	[C_Contact2] [nvarchar](100) NULL,
	[C_Company] [nvarchar](100) NULL,
	[C_Address1] [nvarchar](45) NULL,
	[C_Address2] [nvarchar](45) NULL,
	[C_Address3] [nvarchar](45) NULL,
	[C_Address4] [nvarchar](45) NULL,
	[C_City] [nvarchar](45) NULL,
	[C_State] [nvarchar](45) NULL,
	[C_Zip] [nvarchar](18) NULL,
	[C_Country] [nvarchar](30) NULL,
	[C_ISOCntryCode] [nvarchar](10) NULL,
	[C_Phone1] [nvarchar](18) NULL,
	[C_Phone2] [nvarchar](18) NULL,
	[C_Fax1] [nvarchar](18) NULL,
	[C_Fax2] [nvarchar](18) NULL, 
	[C_vat] [nvarchar](18) NULL,
	[BillToKey] [nvarchar](15) NOT NULL,
	[B_contact1] [nvarchar](100) NULL,
	[B_Contact2] [nvarchar](100) NULL,
	[B_Company] [nvarchar](100) NULL,
	[B_Address1] [nvarchar](45) NULL,
	[B_Address2] [nvarchar](45) NULL,
	[B_Address3] [nvarchar](45) NULL,
	[B_Address4] [nvarchar](45) NULL,
	[B_City] [nvarchar](45) NULL,
	[B_State] [nvarchar](45) NULL,
	[B_Zip] [nvarchar](18) NULL,
	[B_Country] [nvarchar](30) NULL,
	[B_ISOCntryCode] [nvarchar](10) NULL,
	[B_Phone1] [nvarchar](18) NULL,
	[B_Phone2] [nvarchar](18) NULL,
	[B_Fax1] [nvarchar](18) NULL,
	[B_Fax2] [nvarchar](18) NULL,
	[B_Vat] [nvarchar](18) NULL,
	[PmtTerm] [nvarchar](10) NULL,
	[Status] [nvarchar](10) NOT NULL,
	[Type] [nvarchar](10) NOT NULL,
	[OrderGroup] [nvarchar](20) NOT NULL,
	[Door] [nvarchar](10) NOT NULL,
	[Route] [nvarchar](10) NOT NULL,
	[SOStatus] [nvarchar](10) NULL,
	[Rdd] [nvarchar](30) NULL,
	[Rds] [nvarchar](1) NULL,
	[SectionKey] [nvarchar](10) NULL,
	[Facility] [nvarchar](5) NULL,
	[PrintDocDate] [datetime] NULL,
	[LabelPrice] [nvarchar](20) NULL,    --TLTING01
	[POKey] [nvarchar](10) NULL,
	[ExternPOKey] [nvarchar](20) NULL,
	[XDockFlag] [nvarchar](1) NOT NULL,
	[UserDefine01] [nvarchar](20) NULL,
	[UserDefine02] [nvarchar](20) NULL,
	[UserDefine03] [nvarchar](20) NULL,
	[UserDefine04] [nvarchar](40) NULL,   --TLTING03
	[UserDefine05] [nvarchar](20) NULL,
	[UserDefine06] [datetime] NULL,
	[UserDefine07] [datetime] NULL,
	[UserDefine08] [nvarchar](10) NULL,
	[UserDefine09] [nvarchar](10) NULL,
	[UserDefine10] [nvarchar](10) NULL,
	[Issued] [nvarchar](1) NULL,
	[RoutingTool] [nvarchar](30) NULL,
	[DocType] [nvarchar](1) NULL ,
   [ECom_OAID] [nvarchar] (256) NULL,     --kocy01
   [ECOM_Platform] [NVARCHAR] (30) NULL
   )

   INSERT INTO @t_ORDERS
   (
      OrderKey,      StorerKey,        ExternOrderKey,
      Priority,      ConsigneeKey,     C_contact1,
      C_Contact2,    C_Company,        C_Address1,
      C_Address2,    C_Address3,       C_Address4,
      C_City,        C_State,          C_Zip,
      C_Country,     C_ISOCntryCode,   C_Phone1,
      C_Phone2,      C_Fax1,           C_Fax2,
      C_vat,         BillToKey,        B_contact1,
      B_Contact2,    B_Company,        B_Address1,
      B_Address2,    B_Address3,       B_Address4,
      B_City,        B_State,          B_Zip,
      B_Country,     B_ISOCntryCode,   B_Phone1,
      B_Phone2,      B_Fax1,           B_Fax2,
      B_Vat,         PmtTerm,          [Status],
      [Type],        OrderGroup,       Door,
      [Route],       SOStatus,         Rdd,
      Rds,           SectionKey,       Facility,
      PrintDocDate,  LabelPrice,       POKey,
      ExternPOKey,   XDockFlag,        UserDefine01,
      UserDefine02,  UserDefine03,     UserDefine04,
      UserDefine05,  UserDefine06,     UserDefine07,
      UserDefine08,  UserDefine09,     UserDefine10,
      Issued,        RoutingTool,      DocType,
      ECom_OAID,     ECOM_Platform
   )
  SELECT 
      OrderKey,      StorerKey,        ExternOrderKey,
      Priority,      ConsigneeKey,     C_contact1,
      C_Contact2,    C_Company,        C_Address1,
      C_Address2,    C_Address3,       C_Address4,
      C_City,        C_State,          C_Zip,
      C_Country,     C_ISOCntryCode,   C_Phone1,
      C_Phone2,      C_Fax1,           C_Fax2,
      C_vat,         BillToKey,        B_contact1,
      B_Contact2,    B_Company,        B_Address1,
      B_Address2,    B_Address3,       B_Address4,
      B_City,        B_State,          B_Zip,
      B_Country,     B_ISOCntryCode,   B_Phone1,
      B_Phone2,      B_Fax1,           B_Fax2,
      B_Vat,         PmtTerm,          [Status],
      [Type],        OrderGroup,       Door,
      [Route],       SOStatus,         Rdd,
      Rds,           SectionKey,       Facility,
      PrintDocDate,  LabelPrice,       POKey,
      ExternPOKey,   XDockFlag,        UserDefine01,
      UserDefine02,  UserDefine03,     UserDefine04,
      UserDefine05,  UserDefine06,     UserDefine07,
      UserDefine08,  UserDefine09,     UserDefine10,
      Issued,        RoutingTool,      DocType,
      ECom_OAID,     ECOM_Platform
  FROM INSERTED    
   
   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
      GOTO PROCESS_END
   END
   
   IF @n_continue=1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM @t_ORDERS WHERE Facility IS NULL)       
      BEGIN
         UPDATE ORD
            SET Facility = STORER.Facility 
         FROM @t_ORDERS ORD  
         JOIN STORER WITH (NOLOCK) ON STORER.StorerKey = ORD.Storerkey 
         WHERE STORER.Facility IS NOT NULL 
         AND STORER.Facility > '' 

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62311   
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed On orders. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE ORD_ADD_CUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Facility,
             StorerKey,
             Status,       
             OrderKey,     
             ConsigneeKey, 
             TYPE,         
             ISNULL([Route],'')  
        FROM @t_ORDERS

      OPEN ORD_ADD_CUR

      FETCH NEXT FROM ORD_ADD_CUR INTO @c_Facility, @c_StorerKey, @c_ordstatus, @c_OrderKey, @c_ConsigneeKey, @c_OrderType, @c_Route             
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --IF ISNULL(RTRIM(@c_OrderKey), '') = ''
         --   BREAK



         IF @n_continue=1 OR @n_continue = 2
         BEGIN
            SELECT @b_success = 0

            EXECUTE nspGetRight @c_Facility,
                                @c_StorerKey,   -- Storer
                                NULL,           -- No Sku in this Case
                                'AutoUpdateOrderinfo',   -- ConfigKey
                                @b_success          output,
                                @c_Authority_AUOI   output,
                                @n_err              output,
                                @c_errmsg           output

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62301   
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retrieve Failed On GetRight. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' 
               + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK 
            End
         END

         -- Added By SHONG
         -- For OneWorld Interface
         -- Get Storer Configuration -- One World Interfa
         -- Is One World Interface Turn On?
         IF ( @n_continue = 1 OR @n_continue = 2)
         BEGIN
            IF @c_Authority_AUOI IN('1','2') AND @c_ECOM_Orders = 'N'  -- SWT02  
            BEGIN
               IF EXISTS(SELECT 1 FROM @t_ORDERS ORD   
                          WHERE ISNULL(ORD.C_Address1,'') = ''
                            AND ISNULL(ORD.C_Address2,'') = ''
                            AND ISNULL(ORD.C_Address3,'') = ''
                            AND ISNULL(ORD.C_Address4,'') = ''
                            AND ORD.OrderKey = @c_OrderKey)
               BEGIN
                   IF @c_Authority_AUOI = '2' --NJOW02
                   BEGIN
                     UPDATE ORD
                     SET C_Company = Consignee.Company,
                         C_Address1 = Consignee.Address1,
                         C_Address2 = Consignee.Address2,
                         C_Address3 = Consignee.Address3,
                         C_Address4 = Consignee.Address4,
                         C_City = Consignee.City,
                         C_State = Consignee.State,
                         C_Zip = Consignee.Zip,
                         C_Country = Consignee.Country,
                         C_Phone1 = Consignee.Phone1,
                         C_Phone2 = Consignee.Phone2,
                         C_Fax1 = Consignee.Fax1,
                         C_Fax2 = Consignee.Fax2,
                         C_contact1 = Consignee.Contact1,
                         C_contact2 = Consignee.Contact2,
                         Route = CASE WHEN ISNULL(RTRIM(ORD.Route), '') ='' THEN '00000'
                                      ELSE ORD.Route
                                 END
                     FROM @t_ORDERS ORD
                     JOIN Storer AS Consignee With (NOLOCK) ON ( Consignee.StorerKey = ORD.ConsigneeKey )
                     WHERE ISNULL(ORD.C_Address1,'') = ''
                     AND   ISNULL(ORD.C_Address2,'') = ''
                     AND   ISNULL(ORD.C_Address3,'') = ''
                     AND   ISNULL(ORD.C_Address4,'') = ''
                     AND   ORD.OrderKey = @c_OrderKey

                     UPDATE ORD
                     SET B_Company = BillTo.Company,
                         B_Address1 = BillTo.Address1,
                         B_Address2 = BillTo.Address2,
                         B_Address3 = BillTo.Address3,
                         B_Address4 = BillTo.Address4,
                         B_City = BillTo.City,
                         B_State = BillTo.State,
                         B_Zip = BillTo.Zip,
                         B_Country = BillTo.Country,
                         B_Phone1 = BillTo.Phone1,
                         B_Phone2 = BillTo.Phone2,
                         B_Fax1 = BillTo.Fax1,
                         B_Fax2 = BillTo.Fax2,
                         B_contact1 = BillTo.Contact1,
                         B_contact2 = BillTo.Contact2,
                         Route = CASE WHEN ISNULL(RTRIM(ORD.Route),'') ='' THEN '00000'
                                      ELSE ORD.Route
                                 END 
                     FROM @t_ORDERS ORD
                     JOIN Storer AS BillTo With (NOLOCK) ON ( BillTo.StorerKey = ORD.BillToKey )
                     WHERE ISNULL(ORD.B_Address1,'') = ''
                     AND   ISNULL(ORD.B_Address2,'') = ''
                     AND   ISNULL(ORD.B_Address3,'') = ''
                     AND   ISNULL(ORD.B_Address4,'') = ''
                     AND   ORD.OrderKey = @c_OrderKey
                   END -- IF @c_Authority_AUOI = '2'
                   ELSE
                   BEGIN
                     UPDATE ORD
                     SET C_Company = Consignee.Company,
                         C_Address1 = Consignee.Address1,
                         C_Address2 = Consignee.Address2,
                         C_Address3 = Consignee.Address3,
                         C_Address4 = Consignee.Address4,
                         C_City = Consignee.City,
                         C_State = Consignee.State,
                         C_Zip = Consignee.Zip,
                         C_Country = Consignee.Country,
                         C_Phone1 = Consignee.Phone1,
                         C_Phone2 = Consignee.Phone2,
                         C_Fax1 = Consignee.Fax1,
                         C_Fax2 = Consignee.Fax2,
                         C_contact1 = Consignee.Contact1,
                         C_contact2 = Consignee.Contact2,
                         B_Company = BillTo.Company,
                         B_Address1 = BillTo.Address1,
                         B_Address2 = BillTo.Address2,
                         B_Address3 = BillTo.Address3,
                         B_Address4 = BillTo.Address4,
                         B_City = BillTo.City,
                         B_State = BillTo.State,
                         B_Zip = BillTo.Zip,
                         B_Country = BillTo.Country,
                         B_Phone1 = BillTo.Phone1,
                         B_Phone2 = BillTo.Phone2,
                         B_Fax1 = BillTo.Fax1,
                         B_Fax2 = BillTo.Fax2,
                         B_contact1 = BillTo.Contact1,
                         B_contact2 = BillTo.Contact2,
                         Route = CASE WHEN ISNULL(RTRIM(ORD.Route),'') ='' THEN '00000'
                                      ELSE ORD.Route
                                 END 
                     FROM @t_ORDERS ORD
                     JOIN Storer AS Consignee With (NOLOCK) ON ( Consignee.StorerKey = ORD.ConsigneeKey )
                     LEFT OUTER JOIN Storer AS BillTo With (NOLOCK) ON ( BillTo.StorerKey = ORD.BillToKey )
                     WHERE ISNULL(ORD.C_Address1,'') = ''
                     AND   ISNULL(ORD.C_Address2,'') = ''
                     AND   ISNULL(ORD.C_Address3,'') = ''
                     AND   ISNULL(ORD.C_Address4,'') = ''
                     AND   ORD.OrderKey = @c_OrderKey
                  END -- IF @c_Authority_AUOI = '1'

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62303   
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Route Update Failed on ORDERS. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END         	
               END -- IF EXISTS          	
            END
         END
         -- end
         -- Added By SHONG
         -- Date: 22 May 2002
         -- Require By User, Use first 5 chars from extern order key instead of StorerKey
         -- due to inter company sales for same storer.
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            IF @c_Authority_AUOI IN ('1','2') AND @c_ECOM_Orders = 'N'  -- SWT02 
            BEGIN
      	      IF EXISTS(SELECT 1 FROM @t_ORDERS Ord WHERE Ord.UserDefine05 = '' AND Ord.OrderKey = @c_OrderKey) -- SWT02
      	      BEGIN
                  UPDATE ORD
                  SET UserDefine05 = CASE WHEN StorerConfig.StorerKey IS NOT NULL
                                               THEN LEFT(ISNULL(LTrim(ORD.ExternOrderKey),''), 5)
                                          ELSE ORD.StorerKey
                                     END 
                  FROM @t_ORDERS ORD
                  LEFT OUTER JOIN StorerConfig WITH (NOLOCK) ON (StorerConfig.StorerKey = ORD.StorerKey
                                             AND ConfigKey = 'OWITF' AND sValue = '1')
                  WHERE Ord.OrderKey = @c_OrderKey
                  AND ORD.UserDefine05 = ''

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62304  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Route Update Failed on ORDERS. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' 
                           + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END      		
      	      END
            END
         END

         -- Added By SHONG
         -- Date:  27th Jun 2002   -- FBR#6405
         -- The Healthcare Division cannot guarantee that both themselves and J&J
         -- will always remember to update the order header to discrete on order creation
         -- so it is necessary to change the inbound interface of SO to EXceed to ensure that where the
         -- Discrete Order Pick Required flag is set to Yes at Storer Configuration on EXceed,
         -- the order will be updated to EXceed as Discrete.
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            --(Wan01) - START
            EXEC nspGetRight @c_Facility
                          ,  @c_StorerKey   -- Storer
                          ,  NULL         -- No Sku in this Case
                          ,  'KITDSCPICK' -- ConfigKey
                          ,  @b_success      OUTPUT
                          ,  @c_KitDSCPick   OUTPUT
                          ,  @n_err          OUTPUT
                          ,  @c_errmsg       OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
               SET @n_err=62305   
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retrieve Failed On GetRight. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END

            IF @n_continue=1 OR @n_continue = 2
            BEGIN
               IF @c_KitDSCPick > '0'
               BEGIN
                  IF EXISTS ( SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'KIT2SO' AND CODE = @c_StorerKey AND Short = @c_Ordertype ) AND
                     EXISTS ( SELECT 1 FROM @t_ORDERS AS ORDERS  
                              JOIN KIT WITH (NOLOCK) ON (ORDERS.ExternOrderKey = KIT.KitKey AND ORDERS.StorerKey = KIT.StorerKey)
                              WHERE ORDERS.OrderKey = @c_OrderKey    
                              AND ORDERS.Ordergroup = 'KIT' )
                  BEGIN
                     IF @c_KitDSCPick = '1'
                     BEGIN
                        SET @c_UserDefine08 = 'Y'
                     END
                     ELSE IF @c_KitDSCPick = '2'
                     BEGIN
                        SET @c_UserDefine08 = 'N'
                     END
               
                     UPDATE ORD
                        SET UserDefine08 = @c_UserDefine08
                     FROM @t_ORDERS ORD
                     WHERE OrderKey = @c_OrderKey
                  END
               END
               ELSE
               BEGIN
               --(Wan01) - END
                  IF EXISTS( SELECT 1
                             FROM StorerConfig (NOLOCK)
                             WHERE StorerConfig.StorerKey = @c_StorerKey
                               AND ConfigKey = 'DSCPICK' 
                               AND sValue = '1')
                  BEGIN
                     UPDATE ORD
                        SET UserDefine08 = 'Y'
                     FROM @t_ORDERS ORD                      
                     WHERE ORD.UserDefine08 = 'N'
                     AND   ORD.OrderKey = @c_OrderKey
                  END
               --(Wan01) - START
               END

               SET @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err=62306   
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Route Update Failed on ORDERS. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
            --(Wan01) - END
         END
         -- end of 27th Jun Change

         IF ((@n_continue=1 OR @n_continue = 2) AND @c_ECOM_Orders = 'N')  -- SWT02
         BEGIN
            IF (@c_Route = '' OR @c_Route = '99')
            BEGIN 
               SET @c_Route = '99'
        
               SELECT @c_Route = ISNULL([Route], '99')
               FROM STORERSODEFAULT (NOLOCK) 
               WHERE STORERSODEFAULT.StorerKey = @c_ConsigneeKey 
        
               UPDATE ORD 
                  SET [Route] = @c_Route
               FROM @t_ORDERS ORD
               WHERE OrderKey = @c_OrderKey
         
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62307   
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Route Update Failed on ORDERS. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' 
                  + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END                   
            END   
         END

         IF ((@n_continue=1 OR @n_continue = 2) AND @c_ECOM_Orders = 'N')  -- SWT02
         BEGIN
            Select @b_success = 0

            Execute nspGetRight @c_Facility,
                                @c_StorerKey,   -- Storer
                                NULL,           -- No Sku in this Case
                                'Updaterouteinfo', -- ConfigKey
                                @b_success          output,
                                @c_Authority_auri   output,
                                @n_err              output,
                                @c_errmsg           output

            If @b_success <> 1
            Begin
               Select @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62308   
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retrieve Failed On GetRight. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            End
            Else if @c_Authority_auri = 1
            Begin
               -- set route code as address4 of storer table
               UPDATE ORD
               SET route = ISNULL(LEFT(STORER.address4,10), '99'), -- (ChewKP01)
                   c_contact1 = STORER.contact1,
                   c_company  = STORER.company,
                   c_address1 = STORER.address1,
                   c_address2 = STORER.address2,
                   c_address3 = STORER.address3
               FROM @t_ORDERS ORD 
               INNER JOIN STORER (NOLOCK) ON ORD.consigneekey = storer.StorerKey
               WHERE ORD.OrderKey = @c_OrderKey 
            End
         END -- @c_ECOM_Orders = 'N' 

         -- Start : SOS96737 - Copy from Above, C4 MY still uses this
         -- Start : SOS33929
         IF ((@n_continue=1 OR @n_continue = 2) AND @c_ECOM_Orders = 'N')  -- SWT02
         BEGIN
            Select @b_success = 0
            

            Execute nspGetRight @c_Facility,
                                 @c_StorerKey,   -- Storer
                                 NULL,           -- No Sku in this Case
                                 'UpdateXDrouteinfo',  -- ConfigKey
                                 @b_success          output,
                                 @c_Authority_xdroute output,
                                 @n_err              output,
                                 @c_errmsg           output

            If @b_success <> 1
            Begin
               Select @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62309   
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retrieve Failed On GetRight. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            End
            Else if @c_Authority_xdroute = 1
            Begin
               UPDATE ORD
               SET Priority = ISNULL(STORERSODEFAULT.Priority,'5'),
                   Route = ISNULL(STORERSODEFAULT.XDockRoute, '99'),
                   Door =  STORERSODEFAULT.XDockLane
               FROM @t_ORDERS ORD 
               JOIN STORERSODEFAULT (NOLOCK) ON STORERSODEFAULT.StorerKey = ORD.ConsigneeKey
               WHERE ORD.OrderKey = @c_OrderKey 
            End
         END
         -- End : SOS33929
         -- End : SOS96737 - Copy from Above, C4 MY still uses this            

         -- Added by James on 04/10/2007 (SOS80697) Start
         -- If storerconfig 'DefaultRoutingTool' setup (Svalue = '1'), default Orders.RoutingTool = 'Y' (TMSHK)
         IF @n_continue=1 OR @n_continue = 2
         BEGIN
            
            Select @b_success = 0

            Execute nspGetRight @c_Facility,
                                @c_StorerKey,   -- Storer
                                NULL,           -- No Sku in this Case
                                'DefaultRoutingTool', -- ConfigKey
                                @b_success          output,
                                @c_Authority_DefaultRoutingTool    output,
                                @n_err              output,
                                @c_errmsg           output

            If @b_success <> 1
            Begin
               Select @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62310   
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retrieve Failed On GetRight. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            End
            ELSE
            BEGIN
               IF @c_Authority_DefaultRoutingTool = 1
               BEGIN
         	      -- Added By SHONG 23-May-2018 (SWT01)
         	      IF EXISTS(SELECT 1 FROM @t_ORDERS WHERE OrderKey= @c_OrderKey AND RoutingTool <> 'Y' OR RoutingTool IS NULL)
         	      BEGIN
                     UPDATE ORD
                        SET RoutingTool = 'Y' 
                     FROM @t_ORDERS ORD          		
         	      END 
               End
               IF @c_Authority_DefaultRoutingTool <> 1
               BEGIN
                  SELECT @c_Authority_DefaultRoutingTool = ISNULL(sValue, '0')
                  FROM   STORERCONFIG WITH (NOLOCK)
                  WHERE  StorerKey = @c_ConsigneeKey
                  AND    ConfigKey = 'DefaultRoutingTool'
                  AND    sValue = '1'
                  AND    (Facility = '' OR Facility IS NULL)

                  IF @c_Authority_DefaultRoutingTool = 1
                  BEGIN
                     UPDATE ORD
                     SET RoutingTool = 'Y' 
                     FROM @t_ORDERS ORD  
                     WHERE OrderKey= @c_OrderKey
                     AND   ORD.ConsigneeKey = @c_ConsigneeKey
                  END
               END
            END
         END
         -- (SOS80697) END

         -- Start ONG01
         -- Add Control on Update of Priority code with storersodefault value for certain storer
         IF @n_continue=1 OR @n_continue = 2
         BEGIN
            
            Select @b_success = 0

            Execute nspGetRight @c_Facility,
                                @c_StorerKey,   -- Storer
                                NULL,           -- No Sku in this Case
                                'SetPriority4SO',  -- ConfigKey
                                @b_success          output,
                                @c_Authority_priority  output,
                                @n_err              output,
                                @c_errmsg           output

            If @b_success <> 1
            Begin
               Select @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62313   
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retrieve Failed On GetRight. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            End
            Else if @c_Authority_priority = '1'   -- string should be quoted ''
            Begin
               UPDATE ORD
               SET [Priority] = ISNULL(STORERSODEFAULT.[Priority], '99')  
               FROM @t_ORDERS ORD
               LEFT OUTER JOIN STORERSODEFAULT (Nolock) ON (STORERSODEFAULT.StorerKey = ORD.consigneekey)
               WHERE ORD.OrderKey = @c_OrderKey
            End
         END
         -- END ONG01

         -- Added By Vicky 27 June 2003
         -- SOS#12053 - Control on Update of Route code with storersodefault value for certain storer
         IF @n_continue=1 OR @n_continue = 2
         BEGIN
            
            Select @b_success = 0

            Execute nspGetRight @c_Facility,
                                @c_StorerKey,   -- Storer
                                NULL,           -- No Sku in this Case
                                'SetRoute4SOITF',  -- ConfigKey
                                @b_success          output,
                                @c_Authority_SOITF  output,
                                @n_err              output,
                                @c_errmsg           output

            If @b_success <> 1
            Begin
               Select @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=62312   
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retrieve Failed On GetRight. (ntrOrderHeaderPreAdd) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            End
            Else if @c_Authority_SOITF = '1'   -- string should be quoted ''
            Begin
               UPDATE ORD
               SET ORD.route = ISNULL(STORERSODEFAULT.route, '99') 
               FROM @t_ORDERS ORD
               LEFT OUTER JOIN STORERSODEFAULT WITH (NOLOCK) ON (STORERSODEFAULT.StorerKey = ORD.ConsigneeKey)
               WHERE ORD.OrderKey = @c_OrderKey 
            End
         END
         -- END Add SOS#12053
                     
         FETCH NEXT FROM ORD_ADD_CUR INTO @c_Facility, @c_StorerKey, @c_ordstatus, @c_OrderKey, @c_ConsigneeKey, @c_OrderType, @c_Route 
      END -- While Order Record
      CLOSE ORD_ADD_CUR
      DEALLOCATE ORD_ADD_CUR
      -- END -- SOS360858
   END
   
   
   PROCESS_END:
   
   INSERT INTO ORDERS
   (
      OrderKey,            StorerKey,           ExternOrderKey,
      OrderDate,           DeliveryDate,        Priority,
      ConsigneeKey,        C_contact1,          C_Contact2,
      C_Company,           C_Address1,          C_Address2,
      C_Address3,          C_Address4,          C_City,
      C_State,             C_Zip,               C_Country,
      C_ISOCntryCode,      C_Phone1,            C_Phone2,
      C_Fax1,              C_Fax2,              C_vat,
      BuyerPO,             BillToKey,           B_contact1,
      B_Contact2,          B_Company,           B_Address1,
      B_Address2,          B_Address3,          B_Address4,
      B_City,              B_State,             B_Zip,
      B_Country,           B_ISOCntryCode,      B_Phone1,
      B_Phone2,            B_Fax1,              B_Fax2,
      B_Vat,               IncoTerm,            PmtTerm,
      OpenQty,             [Status],            DischargePlace,
      DeliveryPlace,       IntermodalVehicle,   CountryOfOrigin,
      CountryDestination,  UpdateSource,        [Type],
      OrderGroup,          Door,                [Route],
      [Stop],              Notes,               EffectiveDate,
      AddDate,             AddWho,              EditDate,
      EditWho,             TrafficCop,          ArchiveCop,
      ContainerType,       ContainerQty,        BilledContainerQty,
      SOStatus,            MBOLKey,             InvoiceNo,
      InvoiceAmount,       Salesman,            GrossWeight,
      Capacity,            PrintFlag,           LoadKey,
      Rdd,                 Notes2,              SequenceNo,
      Rds,                 SectionKey,          Facility,
      PrintDocDate,        LabelPrice,          POKey,
      ExternPOKey,         XDockFlag,           UserDefine01,
      UserDefine02,        UserDefine03,        UserDefine04,
      UserDefine05,        UserDefine06,        UserDefine07,
      UserDefine08,        UserDefine09,        UserDefine10,
      Issued,              DeliveryNote,        PODCust,
      PODArrive,           PODReject,           PODUser,
      xdockpokey,          SpecialHandling,     RoutingTool,
      MarkforKey,          M_Contact1,          M_Contact2,
      M_Company,           M_Address1,          M_Address2,
      M_Address3,          M_Address4,          M_City,
      M_State,             M_Zip,               M_Country,
      M_ISOCntryCode,      M_Phone1,            M_Phone2,
      M_Fax1,              M_Fax2,              M_vat,
      ShipperKey,          DocType,             TrackingNo,
      ECOM_PRESALE_FLAG,   ECOM_SINGLE_Flag,    CurrencyCode,
      RTNTrackingNo,       HashValue,           BizUnit,
      ECom_OAID,           ECOM_Platform,       CancelReasonCode
   )
SELECT 
      tSO.OrderKey,            tSO.StorerKey,           tSO.ExternOrderKey,
      INS.OrderDate,           INS.DeliveryDate,        tSO.Priority,
      tSO.ConsigneeKey,        tSO.C_contact1,          tSO.C_Contact2,
      tSO.C_Company,           tSO.C_Address1,          tSO.C_Address2,
      tSO.C_Address3,          tSO.C_Address4,          tSO.C_City,
      tSO.C_State,             tSO.C_Zip,               tSO.C_Country,
      tSO.C_ISOCntryCode,      tSO.C_Phone1,            tSO.C_Phone2,
      tSO.C_Fax1,              tSO.C_Fax2,              tSO.C_vat,
      INS.BuyerPO,             tSO.BillToKey,           tSO.B_contact1,
      tSO.B_Contact2,          tSO.B_Company,           tSO.B_Address1,
      tSO.B_Address2,          tSO.B_Address3,          tSO.B_Address4,
      tSO.B_City,              tSO.B_State,             tSO.B_Zip,
      tSO.B_Country,           tSO.B_ISOCntryCode,      tSO.B_Phone1,
      tSO.B_Phone2,            tSO.B_Fax1,              tSO.B_Fax2,
      tSO.B_Vat,               INS.IncoTerm,            tSO.PmtTerm,
      0 AS OpenQty,            tSO.[Status],            INS.DischargePlace,   -- (SWT01) Open Qty Always start with ZERO  
      INS.DeliveryPlace,       INS.IntermodalVehicle,   INS.CountryOfOrigin,
      INS.CountryDestination,  INS.UpdateSource,        tSO.[Type],
      tSO.OrderGroup,          tSO.Door,                tSO.[Route],
      INS.[Stop],              INS.Notes,               INS.EffectiveDate,
      INS.AddDate,             INS.AddWho,              INS.EditDate,
      INS.EditWho,             INS.TrafficCop,          INS.ArchiveCop,
      INS.ContainerType,       INS.ContainerQty,        INS.BilledContainerQty,
      tSO.SOStatus,            INS.MBOLKey,             INS.InvoiceNo,
      INS.InvoiceAmount,       INS.Salesman,            INS.GrossWeight,
      INS.Capacity,            INS.PrintFlag,           INS.LoadKey,
      tSO.Rdd,                 INS.Notes2,              INS.SequenceNo,
      tSO.Rds,                 tSO.SectionKey,          tSO.Facility,
      tSO.PrintDocDate,        tSO.LabelPrice,          tSO.POKey,
      tSO.ExternPOKey,         tSO.XDockFlag,           tSO.UserDefine01,
      tSO.UserDefine02,        tSO.UserDefine03,        tSO.UserDefine04,
      tSO.UserDefine05,        tSO.UserDefine06,        tSO.UserDefine07,
      tSO.UserDefine08,        tSO.UserDefine09,        tSO.UserDefine10,
      tSO.Issued,              INS.DeliveryNote,        INS.PODCust,
      INS.PODArrive,           INS.PODReject,           INS.PODUser,
      INS.xdockpokey,          INS.SpecialHandling,     tSO.RoutingTool,
      INS.MarkforKey,          INS.M_Contact1,          INS.M_Contact2,
      INS.M_Company,           INS.M_Address1,          INS.M_Address2,
      INS.M_Address3,          INS.M_Address4,          INS.M_City,
      INS.M_State,             INS.M_Zip,               INS.M_Country,
      INS.M_ISOCntryCode,      INS.M_Phone1,            INS.M_Phone2,
      INS.M_Fax1,              INS.M_Fax2,              INS.M_vat,
      INS.ShipperKey,          tSO.DocType,             INS.TrackingNo,
      INS.ECOM_PRESALE_FLAG,   INS.ECOM_SINGLE_Flag,    INS.CurrencyCode,
      INS.RTNTrackingNo,       INS.HashValue,           INS.BizUnit,
      INS.ECom_OAID,           INS.ECOM_Platform,       INS.CancelReasonCode 
   FROM @t_ORDERS AS tSO  
   JOIN INSERTED INS ON INS.OrderKey = tSO.OrderKey 
          
END -- End Trigger

GO