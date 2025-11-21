SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_ArchiveUCC                                     */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: Archive UCC Records that already Packed in Pick n Pack      */    
/*          UCC Status change to 6 when UCC# was scanned in PnP         */    
/*                                                                      */    
/* Input Parameters:  @c_copyFROM_db      NVARCHAR(10)                  */    
/*                   ,@c_copyto_db        NVARCHAR(10)                  */    
/*                   ,@n_daysretain       NVARCHAR(10)                  */    
/*                   ,@c_storerkey        NVARCHAR(15)                  */    
/*                   ,@c_status           NVARCHAR(1 )                  */    
/*                                                                      */    
/* Output Parameters: Report                                            */    
/*                                                                      */    
/* Return Status: NONE                                                  */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: Schedule Job                                              */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */     
/* 15-Aug-2005  June      SOS39377 - bug fixed                          */    
/* 08-Jan-2008  June      SOS95268 - Add in daysretain parameter        */    
/* 27-Nov-2008  Ytwan   1.1   SOS121809 -Add parameters storer and      */    
/*                                         status                       */    
/* 15-Dec-2008  TLTING  1.2   SOS124334 -Change filter adddate to       */    
/*                                       EditDate (tlting01)            */    
/* 09-Nov-2010  TLTING  1.3   Commit at line level                      */  
/* 07-Dec-2011  TLTING  1.4   Allow Storerkey & Status parameter blank  */  
/*                            -loop by editdate - unique key for delete */  
/* 22-Oct-2013  TLTING  1.5   Added new Table column                    */  
/* 13-Jun-2014  KHLim   1.6   Added new Table column  (KH01)            */  
/************************************************************************/    
    
CREATE PROC [dbo].[isp_ArchiveUCC]    
  @c_copyFROM_db  NVARCHAR(55),    
  @c_copyto_db    NVARCHAR(55),    
  @n_daysretain   Int = 30, -- June01    
  @c_storerkey    NVARCHAR(15)  = '' , -- SOS121809 YTWan    
  @c_status       NVARCHAR(1)  = ''     -- SOS121809 YTWan    
as    
BEGIN -- main    
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF     
       
   DECLARE @n_continue  int        ,      
      @n_starttcnt      int        , -- holds the current transaction count    
      @n_cnt            int        , -- holds @@rowcount after certain operations    
   @b_debug          int        , -- debug on or off    
      @n_err            int,    
      @c_errmsg         NVARCHAR(254),    
      @b_success        int,    
      @cExecStatements            nvarchar(4000),  -- SOS121809 Ytwan    
      @c_UCCNO          NVARCHAR(20)    
      ,@d_EditDATE       Datetime  
      ,@cExecArguments       nvarchar(4000)   
  
       
   SELECT @n_starttcnt=@@trancount, @n_continue=1,     
          @b_success=0, @n_err=0,     
          @c_errmsg='', @b_debug=1    
       
   IF (@n_continue = 1 or @n_continue = 2)    
   BEGIN      
      IF (@b_debug =1 )    
      BEGIN    
         print 'starting table existence check for ucc...'    
      END    
      SELECT @b_success = 1    
      EXEC nsp_build_archive_table     
         @c_copyFROM_db,     
         @c_copyto_db,     
         'UCC',    
         @b_success output ,     
         @n_err output,     
         @c_errmsg output    
      IF not @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END    
   END    
    
   IF (@n_continue = 1 or @n_continue = 2)    
   BEGIN    
      IF (@b_debug =1 )    
      BEGIN    
         print 'building alter table string for UCC...'    
      END    
          
      EXECUTE nspBuildAlterTableString     
         @c_copyto_db,    
         'UCC',    
         @b_success output,    
         @n_err     output,     
         @c_errmsg  output    
             
      IF NOT @b_success = 1    
      BEGIN    
         SELECT @n_continue = 3    
      END    
   END    
    
   IF (@n_continue = 1 or @n_continue = 2)    
   BEGIN    
      SELECT @c_UCCNO = ''    
  
      DECLARE c_Arch_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT UCCNO, EditDATE  
      FROM UCC WITH (NOLOCK)    
      WHERE ( Storerkey = @c_storerkey OR ISNULL(RTRIM(@c_storerkey), '') = '' ) --tlting02  
      AND   ( Status    = @c_status  OR ISNULL(RTRIM(@c_status), '') = '' )      --tlting02  
      AND   DATEDIFF(DAY, EditDATE, GETDATE()) > @n_daysretain    -- tlting01  
      OPEN c_Arch_UCC    
          
      WHILE(1=1)    
      BEGIN    
         FETCH NEXT FROM c_Arch_UCC INTO @c_UCCNO, @d_EditDATE         
               
         IF @@FETCH_STATUS = -1    
            BREAK    
    
         IF (@b_debug =1 )    
         BEGIN    
            print 'processing UCC: ' + @c_UCCNO   
            PRINT 'editdate: ' + Convert(char(21), @d_EditDATE , 120)   
         END    
    
         SELECT @cExecStatements = N'INSERT INTO ' + dbo.fnc_RTrim(@c_copyto_db) + '..UCC '  +  
                    ' ([UCCNo]
                     ,[Storerkey]
                     ,[ExternKey]
                     ,[SKU]
                     ,[qty]
                     ,[Sourcekey]
                     ,[Sourcetype]
                     ,[Userdefined01]
                     ,[Userdefined02]
                     ,[Userdefined03]
                     ,[Status]
                     ,[AddDate]
                     ,[AddWho]
                     ,[EditDate]
                     ,[EditWho]
                     ,[Lot]
                     ,[Loc]
                     ,[Id]
                     ,[Receiptkey]
                     ,[ReceiptLineNumber]
                     ,[Orderkey]
                     ,[OrderLineNumber]
                     ,[WaveKey]
                     ,[PickDetailKey]
                     ,[Userdefined04]
                     ,[Userdefined05]
                     ,[Userdefined06]
                     ,[Userdefined07]
                     ,[Userdefined08]
                     ,[Userdefined09]
                     ,[Userdefined10]
                     ,[UCC_RowRef]) ' +
                 ' SELECT UCCNo ' +    
                 '       ,Storerkey ' +          
                 '       ,ExternKey ' +           
                 '     ,SKU ' +                 
                 '     ,qty ' +                    
                 '     ,Sourcekey ' +              
                 '     ,Sourcetype ' +             
                 '     ,Userdefined01 ' +          
                 '     ,Userdefined02 ' +          
                 '     ,Userdefined03 ' +          
                 '     ,Status ' +                 
                 '     ,AddDate ' +                
                 '     ,AddWho ' +                 
                 '     ,EditDate ' +               
                 '     ,EditWho ' +                
                 '     ,Lot ' +                    
                 '     ,Loc ' +                    
                 '     ,Id  ' +                    
                 '     ,Receiptkey  ' +            
                 '     ,ReceiptLineNumber ' +      
                 '     ,Orderkey ' +               
                 '     ,OrderLineNumber ' +       
                 '     ,WaveKey  ' +               
                 '     ,PickDetailKey ' +
                 '     ,Userdefined04 ' +
                 '     ,Userdefined05 ' +
                 '     ,Userdefined06 ' +
                 '     ,Userdefined07 ' +
                 '     ,Userdefined08 ' +
                 '     ,Userdefined09 ' +
                 '     ,Userdefined10 ' +                                                                    
                 '     ,UCC_RowRef ' +                                                                    
                 '     FROM ' + dbo.fnc_RTrim(@c_copyFROM_db) + '..UCC WITH (NOLOCK)'  +  
                 ' WHERE UCCNO = @c_UCCNO '  +  
                 ' AND editdate = @d_Editdate '  -- KH01
    
         SET @cExecArguments = N'@c_UCCNO NVARCHAR(20), @d_Editdate datetime '   
         BEGIN TRAN   
         EXEC sp_ExecuteSql @cExecStatements  
                        ,@cExecArguments   
                        ,@c_UCCNO  
                        ,@d_Editdate  
         IF @@error <> 0    
         BEGIN    
            SELECT @n_err = @@error    
            SELECT @c_errmsg = 'insert into archive table failed...'    
            SELECT @n_continue = 3    
            ROLLBACK TRAN  
         END    
         ELSE    
         BEGIN   
            SELECT @cExecStatements = N'delete ' + dbo.fnc_RTrim(@c_copyFROM_db) + '..UCC'  +  
                            ' WHERE UCCNO = @c_UCCNO ' +  
                            ' AND editdate = @d_Editdate '  
  
            SET @cExecArguments = N'@c_UCCNO NVARCHAR(20), @d_Editdate datetime '   
  
            EXEC sp_ExecuteSql @cExecStatements  
                           ,@cExecArguments   
                           ,@c_UCCNO  
                           ,@d_Editdate  
            IF @@error <> 0    
            BEGIN    
               SELECT @n_err = @@error    
               SELECT @c_errmsg = 'insert into archive table failed...'    
               SELECT @n_continue = 3     
               ROLLBACK TRAN  
            END    
         END    
         COMMIT TRAN  
      END -- While     
      CLOSE c_Arch_UCC     
      DEALLOCATE c_Arch_UCC     
   END    
    
   /* #include <sparpo2.sql> */         
   IF @n_continue=3  -- error occured - process AND return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@trancount = 1 AND @@trancount > @n_starttcnt    
      BEGIN    
         rollback tran    
      END    
      ELSE    
      BEGIN    
         WHILE @@trancount > @n_starttcnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      EXECute nsp_logerror @n_err, @c_errmsg, 'isp_archiveucc'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@trancount > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
END -- main  

GO