SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Consolidated_Sheet             				   	*/
/* Creation Date: 01/04/2009                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: ECCO Consolidated Sheet (packing & sorting sheets)          */
/*                                                                      */
/* Called By: r_dw_Consolidated_Sheet                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_Consolidated_Sheet]
	@c_receiptkey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_arcdbname NVARCHAR(30),
           @sql nvarchar(4000)
 
        
   SELECT Receiptkey
   INTO #TEMP_RECEIPT
   FROM Receipt (NOLOCK)  
   WHERE ReceiptKey = @c_receiptkey
   
   IF @@ROWCOUNT = 0
   BEGIN
 	   SELECT @c_arcdbname = NSQLValue FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey='ArchiveDBName'
      
      --IF (SELECT COUNT(*) FROM sys.master_files s_mf
      --  WHERE s_mf.state = 0 and has_dbaccess(db_name(s_mf.database_id)) = 1
      --    AND db_name(s_mf.database_id) = @c_arcdbname) > 0
      IF 1=1
      BEGIN      	
         SET @sql = 'INSERT INTO #TEMP_RECEIPT '
         + '      	SELECT Receiptkey '
         + '      	FROM ' +RTRIM(@c_arcdbname)+ '..Receipt (NOLOCK) '
         + '      	WHERE ReceiptKey = ''' + @c_receiptkey +''''
        EXEC(@sql)
      END
   END
   
   SELECT * FROM #TEMP_RECEIPT
END

GO