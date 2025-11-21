SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger: ntrMasterSerialNoDelete                                        */
/* Creation Date: 29-May-2017                                              */
/* Copyright: LF                                                           */
/* Written by: ChewKP                                                      */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records deleted                                         */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/* 29-May-2017  ChewKP   1.1  WMS-1931 - Created                           */
/***************************************************************************/

CREATE TRIGGER ntrMasterSerialNoDelete ON MasterserialNo 
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

   DECLARE @n_Continue     INT                     
         , @n_StartTCnt    INT            -- Holds the current transaction count    
         , @b_Success      INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err          INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg       NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    
        

   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT     

   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END
   
   IF (@n_Continue = 1 OR @n_Continue = 2) 
   BEGIN 
      INSERT INTO dbo.MasterSerialNoTrn (
                     	 MasterSerialNoKey   ,TranType         ,LocationCode 	,UnitType 	      ,PartnerType 	,SerialNo 	      ,ElectronicSN 	,Storerkey	
                     	,Sku              	,ItemID 	         ,ItemDescr 	   ,ChildQty	      ,ParentSerialNo	,ParentSku 	   ,ParentItemID 	  
                     	,ParentProdLine	   ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	      ,CreationDate	,Source 	      
                     	,Status 	            ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	      ,UserDefine01 	,UserDefine02 	
                     	,UserDefine03 	      ,UserDefine04 	   ,UserDefine05 	 )
      SELECT MasterSerialNoKey   ,'WD'             ,LocationCode 	,UnitType 	      ,PartnerType 	   ,SerialNo 	      ,ElectronicSN 	,Storerkey	
            ,Sku              	,ItemID 	         ,ItemDescr 	   ,ChildQty	      ,ParentSerialNo	,ParentSku 	   ,ParentItemID 	  
            ,ParentProdLine	   ,VendorSerialNo	,VendorLotNo 	,LotNo 	         ,Revision	      ,CreationDate	,Source 	      
            ,Status 	            ,Attribute1 	   ,Attribute2 	,Attribute3       ,RequestID 	      ,UserDefine01 	,UserDefine02 	
            ,UserDefine03 	      ,UserDefine04 	   ,UserDefine05 
      FROM DELETED
      
      IF @@ERROR <> 0 
      BEGIN
          SELECT @n_continue = 3
                ,@n_err = 63320
          SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                 ": Insert into MasterSerialNoTrn Failed - Insert Failed. (ntrMasterSerialNoUpdate)"
      END
   END
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrMasterSerialNoDelete'    
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