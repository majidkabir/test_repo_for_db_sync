SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrPalletMgmtDetailAdd                                         */
/* Creation Date: 04-MAR-2016                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: Pallet Management Maintenance Screen                           */
/*        : PalletMgmtDetail Insert Trigger                                */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Inserted                                        */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author  Ver   Purposes                                     */
/* 01-Jun-2021  NJOW01  1.0   WMS-16767 TH user of to-storer is not allowed*/
/*                            to insert                                    */
/***************************************************************************/
CREATE TRIGGER ntrPalletMgmtDetailAdd ON PALLETMGMTDETAIL
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue         INT                     
         , @n_StartTCnt        INT            -- Holds the current transaction count    
         , @b_Success          INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err              INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg           NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    
         , @b_debug            INT
         , @c_Country          NVARCHAR(30)
         , @c_username         NVARCHAR(128) 
         , @c_StorerRestrict   NVARCHAR(250)     
         , @c_FacilityRestrict NVARCHAR(250)     
         , @c_ToStorerkey      NVARCHAR(15)

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SET @n_continue = 4
      GOTO QUIT
   END

   --Checking
   IF EXISTS ( SELECT 1
               FROM  INSERTED
               JOIN  PALLETMGMT PMH WITH (NOLOCK) ON (INSERTED.PMKey = PMH.PMKey)
               WHERE PMH.Sourcetype = 'ASN'
               AND   INSERTED.Type = 'WD'
              )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 63120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Invalid Withdrawal Transaction type for inbound source type. (ntrPalletMgmtDetailAdd)' 
      GOTO QUIT 
   END

   IF EXISTS ( SELECT 1
               FROM  INSERTED
               JOIN  PALLETMGMT PMH WITH (NOLOCK) ON (INSERTED.PMKey = PMH.PMKey)
               WHERE PMH.Sourcetype IN ('SO', 'LOADPLAN', 'MBOL')
               AND   INSERTED.Status < '9'
               AND   INSERTED.Type = 'DP'
              )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 63130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Invalid Deposit Transaction type for outbound source type. (ntrPalletMgmtDetailAdd)' 
      GOTO QUIT 
   END

  IF EXISTS (  SELECT 1
               FROM  INSERTED
               JOIN  PALLETMGMT PMH WITH (NOLOCK) ON (INSERTED.PMKey = PMH.PMKey)
               JOIN  RECEIPT    RH  WITH (NOLOCK) ON (PMH.Facility   = RH.Facility)
                                                  AND(PMH.SourceKey  = RH.ReceiptKey)
               WHERE PMH.Sourcetype = 'ASN'
               AND   INSERTED.Status < '9'
               AND   INSERTED.FromStorerkey <> '' 
               AND   INSERTED.FromStorerkey <> ISNULL(RH.SellerName,'')
             )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 63140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Invalid From Storer for inbound source transaction #. (ntrPalletMgmtDetailAdd)' 
      GOTO QUIT 
   END

  IF EXISTS (  SELECT 1
               FROM  INSERTED
               JOIN  PALLETMGMT PMH WITH (NOLOCK) ON (INSERTED.PMKey = PMH.PMKey)
               JOIN  RECEIPT    RH  WITH (NOLOCK) ON (PMH.Facility   = RH.Facility)
                                                  AND(PMH.SourceKey  = RH.ReceiptKey)
               WHERE PMH.Sourcetype = 'ASN'
               AND   INSERTED.ToStorerkey <> RH.Storerkey
             )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 63150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Invalid From Storer for inbound source transaction #. (ntrPalletMgmtDetailAdd)' 
      GOTO QUIT 
   END

   IF EXISTS ( SELECT 1
               FROM  INSERTED
               JOIN  PALLETMGMT PMH WITH (NOLOCK) ON (INSERTED.PMKey = PMH.PMKey)
               LEFT JOIN  ORDERS     SO  WITH (NOLOCK) ON (PMH.Facility   = SO.Facility)
                                                       AND(PMH.SourceKey  = SO.Orderkey)
               LEFT JOIN  ORDERS     LP  WITH (NOLOCK) ON (PMH.Facility   = LP.Facility)
                                                       AND(PMH.SourceKey  = LP.Loadkey)
               LEFT JOIN  ORDERS     MB  WITH (NOLOCK) ON (PMH.Facility   = MB.Facility)
                                                       AND(PMH.SourceKey  = MB.Mbolkey)    
               WHERE PMH.Sourcetype IN ( 'SO', 'LOADPLAN', 'MBOL' )
               AND   INSERTED.Status < '9'
               AND   INSERTED.FromStorerkey <> '' AND SO.Orderkey IS NOT NULL AND INSERTED.FromStorerkey <> SO.Storerkey
               AND   INSERTED.FromStorerkey <> '' AND LP.Orderkey IS NOT NULL AND INSERTED.FromStorerkey <> LP.Storerkey
               AND   INSERTED.FromStorerkey <> '' AND MB.Orderkey IS NOT NULL AND INSERTED.FromStorerkey <> MB.Storerkey
              )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 63160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Invalid From Storer for outbound source transaction #. (ntrPalletMgmtDetailAdd)' 
      GOTO QUIT 
   END

   IF EXISTS ( SELECT 1
               FROM  INSERTED
               JOIN  PALLETMGMT PMH WITH (NOLOCK) ON (INSERTED.PMKey = PMH.PMKey)
               LEFT JOIN  ORDERS     SO  WITH (NOLOCK) ON (PMH.Facility   = SO.Facility)
                                                       AND(PMH.SourceKey  = SO.Orderkey)
               LEFT JOIN  ORDERS     LP  WITH (NOLOCK) ON (PMH.Facility   = LP.Facility)
                                                       AND(PMH.SourceKey  = LP.Loadkey)
               LEFT JOIN  ORDERS     MB  WITH (NOLOCK) ON (PMH.Facility   = MB.Facility)
                                                       AND(PMH.SourceKey  = MB.Mbolkey)                                                   
                                                      
               WHERE PMH.Sourcetype IN ( 'SO', 'LOADPLAN', 'MBOL' )
               AND   INSERTED.Status < '9'
               AND   INSERTED.ToStorerkey <> '' AND SO.Orderkey IS NOT NULL AND INSERTED.ToStorerkey <> SO.Consigneekey
               AND   INSERTED.ToStorerkey <> '' AND LP.Orderkey IS NOT NULL AND INSERTED.ToStorerkey <> LP.Consigneekey
               AND   INSERTED.ToStorerkey <> '' AND MB.Orderkey IS NOT NULL AND INSERTED.ToStorerkey <> MB.Consigneekey
              )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 63170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Invalid To Storer for outbound source transaction #. (ntrPalletMgmtDetailAdd)' 
      GOTO QUIT 
   END

   --NJOW01 S
   SELECT @c_Country = NSQLValue 
   FROM NSQLCONFIG (NOLOCK) 
   WHERE ConfigKey = 'COUNTRY'
   
   IF @c_Country  ='TH'
   BEGIN
      SET ANSI_NULLS ON
      SET ANSI_WARNINGS ON
            
      SET @c_username = SUSER_SNAME()
      
      EXEC isp_GetUserRestriction
         @c_username = @c_username  
        ,@c_StorerRestrict = @c_StorerRestrict OUTPUT  
        ,@c_FacilityRestrict = @c_FacilityRestrict OUTPUT  
        ,@b_Success = @b_Success OUTPUT    
        ,@n_Err = @n_Err OUTPUT    
        ,@c_ErrMsg = @c_ErrMsg OUTPUT        
                        
      SET ANSI_NULLS OFF
      SET ANSI_WARNINGS OFF                    
      
      SET @c_ToStorerkey = ''
      SELECT TOP 1 @c_ToStorerkey = I.ToStorerkey
      FROM INSERTED I 
      WHERE I.Type = 'TRF' 
      AND I.ToStorerkey IN (SELECT RTRIM(LTRIM(fds.Colvalue)) FROM dbo.fnc_DelimSplit(',',@c_StorerRestrict) AS fds)        	      
      
      IF ISNULL(@c_ToStorerkey,'') <> ''
      BEGIN      
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(CHAR(250),@n_err)
         SET @n_err = 63180  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Current user of To Storer is Not allowed to Insert. (ntrPalletMgmtDetailAdd)'
                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '         
         GOTO QUIT          
      END
   END   
   --NJOW01 E
   
QUIT:
   /* #INCLUDE <TRRDA2.SQL> */    
   IF @n_Continue=3  -- Error Occured - Process And Return    
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPalletMgmtDetailAdd'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR  

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