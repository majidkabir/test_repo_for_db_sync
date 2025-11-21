SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc : isp_Archive_Order_PI_Encrypted                         */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Input Parameters: NONE                                               */  
/*                                                                      */  
/* OUTPUT Parameters: NONE                                              */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: nspArchiveShippingOrder                                   */  
/*                                                                      */  
/* PVCS Version:1.1                                                     */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */   
/************************************************************************/  
  
CREATE   PROC [dbo].[isp_Archive_Order_PI_Encrypted]  
   @c_copyfrom_db             NVARCHAR(55),  
   @c_copyto_db               NVARCHAR(55),  
   @copyrowstoarchivedatabase NVARCHAR(1),  
   @b_success                 int OUTPUT  
AS  
/*--------------------------------------------------------------*/  
-- THIS ARCHIVE SCRIPT IS EXECUTED FROM nsparchiveshippingorder  
/*--------------------------------------------------------------*/  
BEGIN -- main  
  
   /* BEGIN 2005-Aug-10 (SOS38267) */  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   /* END 2005-Aug-10 (SOS38267) */  
  
   DECLARE @n_continue int,  
           @n_starttcnt int, -- holds the current transaction count  
           @n_cnt int,       -- holds @@rowcount after certain operations  
           @b_debug int      -- debug on or off  
  
   /* #include <sparpo1.sql> */  
   DECLARE @n_archive_OrderEncrypted_records        int, -- # of MBOL records to be archived  
           @n_archive_mbol_Detail_records int, -- # of MBOLDetail records to be archived  
           @n_err                         int,  
           @c_errmsg                      NVARCHAR(254),  
           @local_n_err                   int,  
           @local_c_errmsg                NVARCHAR(254),  
           @c_temp                        NVARCHAR(254)  
  
   DECLARE @c_SQLStatement  NVARCHAR(4000),  
           @c_SQLParm NVARCHAR(4000)  

  
   SELECT @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',  
          @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '  
  
  DECLARE 
   @n_Rowrefkey  BIGINT,
   @c_OrderKey   [NVARCHAR](10), 
	@c_C_Contact1 [NVARCHAR](200) ='',
	@c_C_Contact2 [NVARCHAR](200) ='',
	@c_C_Company  [NVARCHAR](45) ='',
	@c_C_Address1 [NVARCHAR](45) ='',
	@c_C_Address2 [NVARCHAR](45) ='',
	@c_C_Address3 [NVARCHAR](45) ='',
	@c_C_Address4 [NVARCHAR](45) ='',
	@c_C_City     [NVARCHAR](45) ='',
	@c_C_State    [NVARCHAR](45) ='',
	@c_C_Zip      [NVARCHAR](18) ='',
   @c_C_Country  [NVARCHAR](30) ='',
	@c_C_Phone1   [NVARCHAR](18) ='',
	@c_C_Phone2   [NVARCHAR](18) ='',
	@c_C_Fax1     [NVARCHAR](18) ='',
   @c_C_Fax2     [NVARCHAR](18) ='',
	@c_B_Contact1 [NVARCHAR](200) ='',
	@c_B_Contact2 [NVARCHAR](200) ='',
	@c_B_Company  [NVARCHAR](45) ='',
	@c_B_Address1 [NVARCHAR](45) ='',
	@c_B_Address2 [NVARCHAR](45) ='',
	@c_B_Address3 [NVARCHAR](45) ='',
	@c_B_Address4 [NVARCHAR](45) ='',
	@c_B_City     [NVARCHAR](45) ='',
	@c_B_State    [NVARCHAR](45) ='',
	@c_B_Zip      [NVARCHAR](18) ='',
   @c_B_Country  [NVARCHAR](30) ='',
	@c_B_Phone1   [NVARCHAR](18) ='',
	@c_B_Phone2   [NVARCHAR](18) ='',
	@c_B_Fax1     [NVARCHAR](18) ='',
   @c_B_Fax2     [NVARCHAR](18) ='',
	@c_M_Contact1 [NVARCHAR](200) ='',
	@c_M_Contact2 [NVARCHAR](200) ='',
	@c_M_Company  [NVARCHAR](45) ='',
	@c_M_Address1 [NVARCHAR](45) ='',
	@c_M_Address2 [NVARCHAR](45) ='',
	@c_M_Address3 [NVARCHAR](45) ='',
	@c_M_Address4 [NVARCHAR](45) ='',
	@c_M_City     [NVARCHAR](45) ='',
	@c_M_State    [NVARCHAR](45) ='',
	@c_M_Zip      [NVARCHAR](18) ='',
   @c_M_Country  [NVARCHAR](30) ='',
	@c_M_Phone1   [NVARCHAR](18) ='',
	@c_M_Phone2   [NVARCHAR](18) ='',
	@c_M_Fax1     [NVARCHAR](18) ='',
   @c_M_Fax2     [NVARCHAR](18) ='',
   @dt_AddDate    datetime = NULL,
   @c_AddWho      Nvarchar(128) = '',
   @dt_EditDate   datetime = NULL,
   @c_EditWho     Nvarchar(128) = '',
   @c_ArchiveCop  Nvarchar(1) = ''

   IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')  
   BEGIN  
      IF (@b_debug =1 )  
      BEGIN  
         PRINT 'starting table existence check for Orders_PI_Encrypted...'  
      END  
      SELECT @b_success = 1  
      EXEC nsp_build_archive_table  
            @c_copyfrom_db,  
            @c_copyto_db,  
            'Orders_PI_Encrypted',  
            @b_success OUTPUT,  
            @n_err     OUTPUT,  
            @c_errmsg  OUTPUT  
      IF NOT @b_success = 1  
      BEGIN  
         SELECT @n_continue = 3  
      END  
   END  
  
   IF ((@n_continue = 1 or @n_continue = 2) AND @copyrowstoarchivedatabase = 'y')  
   BEGIN  
      IF (@b_debug =1 )  
      BEGIN  
         PRINT 'building alter table string for Orders_PI_Encrypted...'  
      END  
      EXECUTE nspbuildaltertablestring  
            @c_copyto_db,  
            'Orders_PI_Encrypted',  
            @b_success OUTPUT,  
            @n_err     OUTPUT,  
            @c_errmsg  OUTPUT  
      IF NOT @b_success = 1  
      BEGIN  
         SELECT @n_continue = 3  
      END  
   END  
     
   WHILE @@trancount > 0  
      COMMIT TRAN  
  
   SELECT @n_archive_OrderEncrypted_records = 0   

   IF (@b_debug =1 )  
   BEGIN  
      PRINT 'Loop Orders_PI_Encrypted ...'  
   END  

   Declare @t_Orders_PI_Decrypted TABLE   
   (  
    OrderKey NVARCHAR(10),  
      C_Contact1 [NVARCHAR](200),  
      C_Contact2 [NVARCHAR](200),  
      C_Company  [NVARCHAR](45),  
      C_Address1 [NVARCHAR](45),  
      C_Address2 [NVARCHAR](45),  
      C_Address3 [NVARCHAR](45),  
      C_Address4 [NVARCHAR](45),  
      C_City     [NVARCHAR](45),  
      C_State    [NVARCHAR](45),  
      C_Zip      [NVARCHAR](18),
 --     C_Country  [NVARCHAR](30),      
      C_Phone1   [NVARCHAR](18),  
      C_Phone2   [NVARCHAR](18),  
      C_Fax1     [NVARCHAR](18),  
      C_Fax2     [NVARCHAR](18),  
      B_Contact1 [NVARCHAR](200),  
      B_Contact2 [NVARCHAR](200),  
      B_Company  [NVARCHAR](45),  
      B_Address1 [NVARCHAR](45),  
      B_Address2 [NVARCHAR](45),  
      B_Address3 [NVARCHAR](45),  
      B_Address4 [NVARCHAR](45),  
      B_City     [NVARCHAR](45),  
      B_State    [NVARCHAR](45),
      B_Zip      [NVARCHAR](18),  
 --     B_Country  [NVARCHAR](30),
      B_Phone1   [NVARCHAR](18),  
      B_Phone2   [NVARCHAR](18),  
      B_Fax1     [NVARCHAR](18),  
      B_Fax2     [NVARCHAR](18),  
      M_Contact1 [NVARCHAR](200),  
      M_Contact2 [NVARCHAR](200),  
      M_Company  [NVARCHAR](45),  
      M_Address1 [NVARCHAR](45),  
      M_Address2 [NVARCHAR](45),  
      M_Address3 [NVARCHAR](45),  
      M_Address4 [NVARCHAR](45),  
      M_City     [NVARCHAR](45),  
      M_State    [NVARCHAR](45),  
      M_Zip      [NVARCHAR](18),
  --    M_Country  [NVARCHAR](30),      
      M_Phone1   [NVARCHAR](18),  
      M_Phone2   [NVARCHAR](18),  
      M_Fax1     [NVARCHAR](18),  
      M_Fax2     [NVARCHAR](18)       
   )  
      
   DECLARE C_Orders_Encrypted CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Orderkey,   Rowrefkey,  AddDate,    AddWho, 
             EditDate,   EditWho,    ArchiveCop
      FROM  Orders_PI_Encrypted WITH (NOLOCK)  
      WHERE ArchiveCop  = '9'  
      ORDER BY Orderkey  
  
   OPEN C_Orders_Encrypted  
   FETCH NEXT FROM C_Orders_Encrypted INTO @c_OrderKey, @n_Rowrefkey, @dt_AddDate, @c_AddWho, @dt_EditDate, @c_EditWho, @c_ArchiveCop
                       
   WHILE @@fetch_status <> -1 AND (@n_continue = 1 or @n_continue = 2)  
   BEGIN  
      DELETE FROM  @t_Orders_PI_Decrypted
       
      INSERT INTO @t_Orders_PI_Decrypted
      Exec  [dbo].[isp_Get_Order_PI_Encrypted]  
            @c_OrderKey   = @c_OrderKey,
            @b_success    = @b_success OUTPUT, 
            @n_ErrNo      = @n_err OUTPUT,
            @c_ErrMsg     = @c_ErrMsg OUTPUT 
             
      IF (@b_debug =1 )  
      BEGIN  
         PRINT ' >> Orderkey - ' + @c_OrderKey 
      END      
     
      SELECT 
         @c_C_Contact1  = C_Contact1,
         @c_C_Contact2  = C_Contact2,
         @c_C_Company   = C_Company,
         @c_C_Address1  = C_Address1,
         @c_C_Address2  = C_Address2,
         @c_C_Address3  = C_Address3,
         @c_C_Address4  = C_Address4,
         @c_C_City      = C_City,
         @c_C_State     = C_State,
         @c_C_Zip       = C_Zip,
   --      @c_C_Country   = C_Country,
         @c_C_Phone1    = C_Phone1,
         @c_C_Phone2    = C_Phone2,
         @c_C_Fax1      = C_Fax1,
         @c_C_Fax2      = C_Fax2,
         @c_B_Contact1  = B_Contact1,
         @c_B_Contact2  = B_Contact2,
         @c_B_Company   = B_Company,
         @c_B_Address1  = B_Address1,
         @c_B_Address2  = B_Address2,
         @c_B_Address3  = B_Address3,
         @c_B_Address4  = B_Address4,
         @c_B_City      = B_City,
         @c_B_State     = B_State,
         @c_B_Zip       = B_Zip,
 --        @c_B_Country   = B_Country,
         @c_B_Phone1    = B_Phone1,
         @c_B_Phone2    = B_Phone2,
         @c_B_Fax1      = B_Fax1,
         @c_B_Fax2      = B_Fax2,       
         @c_M_Contact1  = M_Contact1,
         @c_M_Contact2  = M_Contact2,
         @c_M_Company   = M_Company,
         @c_M_Address1  = M_Address1,
         @c_M_Address2  = M_Address2,
         @c_M_Address3  = M_Address3,
         @c_M_Address4  = M_Address4,
         @c_M_City      = M_City,
         @c_M_State     = M_State,
         @c_M_Zip       = M_Zip,
  --       @c_M_Country   = M_Country,
         @c_M_Phone1    = M_Phone1,
         @c_M_Phone2    = M_Phone2,
         @c_M_Fax1      = M_Fax1,
         @c_M_Fax2      = M_Fax2     
         FROM @t_Orders_PI_Decrypted    
         WHERE OrderKey = @c_OrderKey;  	
  
      SELECT @local_n_err = @@error, @n_cnt = @@rowcount  
      SELECT @n_archive_OrderEncrypted_records = @n_archive_OrderEncrypted_records + 1  
  
      IF @local_n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @local_n_err = 77303  
         SELECT @local_c_errmsg = CONVERT(NVARCHAR(5),@local_n_err)  
         SELECT @local_c_errmsg = ': SELECT of ArchiveCop failed - Orders_PI_Encrypted. (isp_Archive_Order_PI_Encrypted) ' + ' ( ' +  
                                    ' sqlsvr message = ' + LTRIM(RTRIM(@local_c_errmsg)) + ')'                
      END  
  
      IF (@b_debug =1 )  
      BEGIN  
         PRINT ' >> Pass to - ' + @c_copyto_db   
         Print ' C_Company - ' + @c_C_Company
      END
      BEGIN TRAN 
      SELECT @c_SQLStatement =  --'USE ' + @c_copyto_db + '  ' + Char(13) +
                           'EXEC ' + @c_copyto_db + '.dbo.isp_Create_Order_PI_Encrypted_Archive ' +
                           '  @n_Rowrefkey  = @n_Rowrefkey  ' +
                           ' ,@c_OrderKey   = @c_OrderKey   ' +
                           ' ,@c_C_Contact1 = @c_C_Contact1 ' +
                           ' ,@c_C_Contact2 = @c_C_Contact2 ' +
                           ' ,@c_C_Company  = @c_C_Company  ' +
                           ' ,@c_C_Address1 = @c_C_Address1 ' +
                           ' ,@c_C_Address2 = @c_C_Address2 ' +
                           ' ,@c_C_Address3 = @c_C_Address3 ' +
                           ' ,@c_C_Address4 = @c_C_Address4 ' +
                           ' ,@c_C_City     = @c_C_City     ' +
                           ' ,@c_C_State    = @c_C_State    ' +
                           ' ,@c_C_Zip      = @c_C_Zip      ' +
                        --   ' ,@c_C_Country  = @c_C_Country  ' +
                           ' ,@c_C_Phone1   = @c_C_Phone1   ' +
                           ' ,@c_C_Phone2   = @c_C_Phone2   ' +
                           ' ,@c_C_Fax1     = @c_C_Fax1     ' +
                           ' ,@c_C_Fax2     = @c_C_Fax2     ' +
                           ' ,@c_B_Contact1 = @c_B_Contact1 ' +
                           ' ,@c_B_Contact2 = @c_B_Contact2 ' +
                           ' ,@c_B_Company  = @c_B_Company  ' +
                           ' ,@c_B_Address1 = @c_B_Address1 ' +
                           ' ,@c_B_Address2 = @c_B_Address2 ' +
                           ' ,@c_B_Address3 = @c_B_Address3 ' +
                           ' ,@c_B_Address4 = @c_B_Address4 ' +
                           ' ,@c_B_City     = @c_B_City     ' +
                           ' ,@c_B_State    = @c_B_State    ' +
                           ' ,@c_B_Zip      = @c_B_Zip      ' +
                       --    ' ,@c_B_Country  = @c_B_Country  ' +
                           ' ,@c_B_Phone1   = @c_B_Phone1   ' +
                           ' ,@c_B_Phone2   = @c_B_Phone2   ' +
                           ' ,@c_B_Fax1     = @c_B_Fax1     ' +
                           ' ,@c_B_Fax2     = @c_B_Fax2     ' +
                           ' ,@c_M_Contact1 = @c_M_Contact1 ' +
                           ' ,@c_M_Contact2 = @c_M_Contact2 ' +
                           ' ,@c_M_Company  = @c_M_Company  ' +
                           ' ,@c_M_Address1 = @c_M_Address1 ' +
                           ' ,@c_M_Address2 = @c_M_Address2 ' +
                           ' ,@c_M_Address3 = @c_M_Address3 ' +
                           ' ,@c_M_Address4 = @c_M_Address4 ' +
                           ' ,@c_M_City     = @c_M_City     ' +
                           ' ,@c_M_State    = @c_M_State    ' +
                           ' ,@c_M_Zip      = @c_M_Zip      ' +
                        --   ' ,@c_M_Country  = @c_M_Country  ' +
                           ' ,@c_M_Phone1   = @c_M_Phone1   ' +
                           ' ,@c_M_Phone2   = @c_M_Phone2   ' +
                           ' ,@c_M_Fax1     = @c_M_Fax1     ' +
                           ' ,@c_M_Fax2     = @c_M_Fax2     ' +
                           ' ,@dt_AddDate   = @dt_AddDate   ' +
                           ' ,@c_AddWho     = @c_AddWho     ' +
                           ' ,@dt_EditDate  = @dt_EditDate  ' +
                           ' ,@c_EditWho    = @c_EditWho    ' +
                           ' ,@c_ArchiveCop = @c_ArchiveCop ' +
                           ' ,@b_success    = @b_success OUTPUT ' +
                           ' ,@n_ErrNo      = @n_ErrNo OUTPUT ' +
                           ' ,@c_ErrMsg     = @c_ErrMsg OUTPUT '



       SET @c_SQLParm =  
         N' @n_Rowrefkey  BIGINT,          ' +
          ' @c_OrderKey   [NVARCHAR](10),      ' +
	       ' @c_C_Contact1 [NVARCHAR](200), ' +
	       ' @c_C_Contact2 [NVARCHAR](200), ' +
	       ' @c_C_Company  [NVARCHAR](45),  ' +
	       ' @c_C_Address1 [NVARCHAR](45),  ' +
	       ' @c_C_Address2 [NVARCHAR](45),  ' +
	       ' @c_C_Address3 [NVARCHAR](45),  ' +
	       ' @c_C_Address4 [NVARCHAR](45),  ' +
	       ' @c_C_City     [NVARCHAR](45),  ' +
	       ' @c_C_State    [NVARCHAR](45),  ' +
	       ' @c_C_Zip      [NVARCHAR](18),  ' +
       --   ' @c_C_Country  [NVARCHAR](30),  ' +
	       ' @c_C_Phone1   [NVARCHAR](18),  ' +
	       ' @c_C_Phone2   [NVARCHAR](18),  ' +
	       ' @c_C_Fax1     [NVARCHAR](18),  ' +
          ' @c_C_Fax2     [NVARCHAR](18),  ' +
	       ' @c_B_Contact1 [NVARCHAR](200), ' +
	       ' @c_B_Contact2 [NVARCHAR](200), ' +
	       ' @c_B_Company  [NVARCHAR](45) , ' +
	       ' @c_B_Address1 [NVARCHAR](45) , ' +
	       ' @c_B_Address2 [NVARCHAR](45) , ' +
	       ' @c_B_Address3 [NVARCHAR](45) , ' +
	       ' @c_B_Address4 [NVARCHAR](45) , ' +
	       ' @c_B_City     [NVARCHAR](45) , ' +
	       ' @c_B_State    [NVARCHAR](45) , ' +
	       ' @c_B_Zip      [NVARCHAR](18) , ' +
        --  ' @c_B_Country  [NVARCHAR](30) , ' +
	       ' @c_B_Phone1   [NVARCHAR](18) , ' +
	       ' @c_B_Phone2   [NVARCHAR](18) , ' +
	       ' @c_B_Fax1     [NVARCHAR](18) , ' +
          ' @c_B_Fax2     [NVARCHAR](18) , ' +
	       ' @c_M_Contact1 [NVARCHAR](200), ' +
	       ' @c_M_Contact2 [NVARCHAR](200), ' +
	       ' @c_M_Company  [NVARCHAR](45) , ' +
	       ' @c_M_Address1 [NVARCHAR](45) , ' +
	       ' @c_M_Address2 [NVARCHAR](45) , ' +
	       ' @c_M_Address3 [NVARCHAR](45) , ' +
	       ' @c_M_Address4 [NVARCHAR](45) , ' +
	       ' @c_M_City     [NVARCHAR](45) , ' +
	       ' @c_M_State    [NVARCHAR](45) , ' +
	       ' @c_M_Zip      [NVARCHAR](18) , ' +
       --   ' @c_M_Country  [NVARCHAR](30) , ' +
	       ' @c_M_Phone1   [NVARCHAR](18) , ' +
	       ' @c_M_Phone2   [NVARCHAR](18) , ' +
	       ' @c_M_Fax1     [NVARCHAR](18) , ' +
          ' @c_M_Fax2     [NVARCHAR](18) , ' +
          ' @dt_AddDate    datetime  ,     ' +
          ' @c_AddWho      Nvarchar(128),  ' +
          ' @dt_EditDate   datetime ,      ' +
          ' @c_EditWho     Nvarchar(128) , ' +
          ' @c_ArchiveCop  Nvarchar(1),     ' +
          ' @b_success  INT  OUTPUT,  ' +
          ' @n_ErrNo    INT  OUTPUT, ' +
          ' @c_ErrMsg   NVARCHAR(250)   OUTPUT '

         EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm
              , @n_Rowrefkey  
              , @c_OrderKey   
              , @c_C_Contact1 
              , @c_C_Contact2 
              , @c_C_Company  
              , @c_C_Address1 
              , @c_C_Address2 
              , @c_C_Address3 
              , @c_C_Address4 
              , @c_C_City     
              , @c_C_State    
              , @c_C_Zip      
          --    , @c_C_Country  
              , @c_C_Phone1   
              , @c_C_Phone2   
              , @c_C_Fax1     
              , @c_C_Fax2     
              , @c_B_Contact1 
              , @c_B_Contact2 
              , @c_B_Company  
              , @c_B_Address1 
              , @c_B_Address2 
              , @c_B_Address3 
              , @c_B_Address4 
              , @c_B_City     
              , @c_B_State    
              , @c_B_Zip      
        --      , @c_B_Country  
              , @c_B_Phone1   
              , @c_B_Phone2   
              , @c_B_Fax1     
              , @c_B_Fax2     
              , @c_M_Contact1 
              , @c_M_Contact2 
              , @c_M_Company  
              , @c_M_Address1 
              , @c_M_Address2 
              , @c_M_Address3 
              , @c_M_Address4 
              , @c_M_City     
              , @c_M_State    
              , @c_M_Zip      
         --     , @c_M_Country  
              , @c_M_Phone1   
              , @c_M_Phone2   
              , @c_M_Fax1     
              , @c_M_Fax2     
              , @dt_AddDate   
              , @c_AddWho     
              , @dt_EditDate  
              , @c_EditWho    
              , @c_ArchiveCop 
              , @b_success OUTPUT
              , @n_Err  OUTPUT
              , @c_ErrMsg  OUTPUT

         FETCH NEXT FROM C_Orders_Encrypted INTO @c_OrderKey, @n_Rowrefkey, @dt_AddDate, @c_AddWho, @dt_EditDate, @c_EditWho, @c_ArchiveCop  
      END  
      CLOSE C_Orders_Encrypted  
      DEALLOCATE C_Orders_Encrypted  
  
 --     CLOSE SYMMETRIC KEY Smt_Key_Orders_PI


   IF ((@n_continue = 1 or @n_continue = 2)  AND @copyrowstoarchivedatabase = 'y')  
   BEGIN  
      SELECT @c_temp = 'attempting to archive ' + RTRIM(CONVERT(NVARCHAR(6),@n_archive_OrderEncrypted_records )) +  
                       ' MBOL records  '  
      EXECUTE nsplogalert  
               @c_modulename   = 'isp_Archive_Order_PI_Encrypted',  
               @c_alertmessage = @c_temp ,  
               @n_severity     = 0,  
               @b_success      = @b_success OUTPUT,  
               @n_err          = @n_err     OUTPUT,  
               @c_errmsg       = @c_errmsg  OUTPUT  
      IF NOT @b_success = 1  
      BEGIN  
         SELECT @n_continue = 3  
      END  
   END  
  
   WHILE @@trancount > 0  
      COMMIT TRAN  

   QUICK_SP:

   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @b_success = 1  
      EXECUTE nsplogalert  
               @c_modulename   = 'isp_Archive_Order_PI_Encrypted',  
               @c_alertmessage = 'archive of MBOL ended successfully.',  
               @n_severity     = 0,  
               @b_success      = @b_success OUTPUT,  
               @n_err          = @n_err     OUTPUT,  
               @c_errmsg       = @c_errmsg  OUTPUT  
      IF NOT @b_success = 1  
      BEGIN  
         SELECT @n_continue = 3  
      END  
   END  
   ELSE  
   BEGIN  
      IF @n_continue = 3  
      BEGIN  
         SELECT @b_success = 1  
         EXECUTE nsplogalert  
                  @c_modulename   = 'isp_Archive_Order_PI_Encrypted',  
                  @c_alertmessage = 'archive of MBOL failed - check this log for additional messages.',  
                  @n_severity     = 0,  
                  @b_success      = @b_success OUTPUT,  
                  @n_err          = @n_err     OUTPUT,  
                  @c_errmsg       = @c_errmsg  OUTPUT  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
      END  
   END  
END -- main  

GO