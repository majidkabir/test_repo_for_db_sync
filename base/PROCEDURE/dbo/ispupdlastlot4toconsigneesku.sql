SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Stored Procedure: ispUpdLastLot4ToConsigneeSku                         */
/* Creation Date: 28-Nov-2013                                             */
/* Copyright: LF                                                          */
/* Written by: NJOW                                                       */
/*                                                                        */
/* Purpose: SOS#296197 - P&G - Smart Allocation - Update Consigneesku     */
/*                                                                        */
/* Called By: SQL Schedular Job                                           */
/*                                                                        */
/*                                                                        */
/* PVCS Version: 1.0                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author   Ver  Purposes                                    */
/* 20-DEC-2013  YTWan    1.1  SOS#296197 - Specification Change.(Wan01)   */
/* 01-Dec-2014  NJOW01   1.2  326780-Carter for HHT conditions            */
/* 22-Mar-2017  NJOW02   1.3  WMS-1110 allow all status for LOR           */
/* 03-Jul-2018  NJOW03   1.4  WMS-4940 allow ENG for any order type       */
/* 16-Jan-2020  WLChooi  1.5  WMS-11784 Check UDF01 before updating (WL01)*/
/* 14-Sep-2020  NJOW04   1.6  WMS-15160 use codelkup to filter order type */
/**************************************************************************/
CREATE PROCEDURE [dbo].[ispUpdLastLot4ToConsigneeSku]
   @c_Storerkey  NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @n_Continue     INT,   
           @b_success      INT,
           @n_err          INT,
           @c_errmsg       NVARCHAR(250),    
           @n_starttcnt    INT,
           @c_Sku          NVARCHAR(20),
           @c_Consigneekey NVARCHAR(15),
           @dt_lottable04  DATETIME,
           @c_UDF01        NVARCHAR(10) = '',   --WL01
           @c_Code         NVARCHAR(30)
   
   --NJOW04        
   SELECT TOP 1 @c_Code = Code 
   FROM CODELKUP (NOLOCK) 
   WHERE Storerkey = @c_Storerkey 
   AND Listname = 'UPDCSSKU' 
   AND Long = 'ispUpdLastLot4ToConsigneeSku'
   ORDER BY CASE WHEN CHARINDEX('%', Code) > 0 THEN 1 ELSE 2 END, Code

   SELECT @n_starttcnt=@@TRANCOUNT, @n_Err=0, @b_Success=1, @c_ErrMsg='', @n_Continue = 1
   BEGIN TRAN
   	
   DECLARE LASTPICKEXP_CUR CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT O.Consigneekey, 
             PD.Sku, 
             MAX(AR.Lottable04)  --+1    -- (Wan01)  
      FROM PICKDETAIL PD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON O.Orderkey = PD.Orderkey
      JOIN STORER S (NOLOCK) ON S.Storerkey = O.Consigneekey
      JOIN DOCLKUP LK (NOLOCK) ON LK.Consigneegroup = S.Secondary
      JOIN SKU (NOLOCK) ON LK.Skugroup = SKU.Skugroup AND SKU.Storerkey = PD.Storerkey AND SKU.Sku = PD.Sku
      JOIN LOTATTRIBUTE AR (NOLOCK) ON AR.Lot = PD.Lot
      WHERE O.Storerkey = @c_Storerkey 
      AND O.Status = '9' 
      --AND O.Type LIKE CASE WHEN @c_Storerkey = 'HHT' THEN 'NORMAL%' 
      --                     WHEN @c_Storerkey IN ('LOR','ENG') THEN '%' --NJOW02 NJOW03
      --                     ELSE 'Z%' END --NJOW01
      AND (O.Type IN (SELECT Code FROM CODELKUP (NOLOCK) WHERE Storerkey = @c_Storerkey AND Listname = 'UPDCSSKU' AND Long = 'ispUpdLastLot4ToConsigneeSku') --NJOW04
          OR O.Type LIKE @c_Code)
      AND LK.Userdefine01 = CASE WHEN @c_Storerkey = 'HHT' THEN 'HHT' ELSE LK.Userdefine01 END  --NJOW01
      AND LK.Userdefine02 = 'CONSIGNEESKU'
      AND O.Editdate > CONVERT( NVARCHAR(8), GETDATE()-1, 112)
      GROUP BY O.Consigneekey, PD.Sku

	    OPEN LASTPICKEXP_CUR
      
	    FETCH NEXT FROM LASTPICKEXP_CUR INTO @c_Consigneekey, @c_Sku, @dt_lottable04
      
	    WHILE @@FETCH_STATUS <> -1
	    BEGIN
          IF NOT EXISTS (SELECT 1 FROM CONSIGNEESKU C (NOLOCK) 
	    	                WHERE C.Consigneekey = @c_Consigneekey
	    	                --AND C.Consigneesku = @c_SKU
	    	                AND C.Storerkey = @c_Storerkey
	    	                AND C.Sku = @c_Sku)
          BEGIN
	    	 	  INSERT INTO CONSIGNEESKU (Consigneekey, ConsigneeSku, Storerkey, Sku, UDF01)
	    	 	  VALUES (@c_Consigneekey, @c_Sku, @c_Storerkey, @c_Sku, CONVERT(NVARCHAR(8),@dt_lottable04,112))
	    	 	  
             IF @@ERROR <> 0 
             BEGIN
                SELECT @n_continue = 3
                SELECT @n_Err = 31211
                SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
                                   'Error Insert ConsigneeSKU Table (ispUpdLastLot4ToConsigneeSku)'
             END          
          END
	    	 ELSE
          BEGIN
             --WL01 Start
             IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK) WHERE CL.LISTNAME = 'REPORTCFG' AND CL.STORERKEY = @c_Storerkey
                                                             AND CL.SHORT = 'Y' AND CL.LONG = 'ispUpdLastLot4ToConsigneeSku'
                                                             AND CL.CODE = 'DoNotUpdateUDF01IfNewer')
             BEGIN
                SELECT @c_UDF01 = CAST(ISNULL(UDF01,'') AS NVARCHAR(8))
                FROM ConsigneeSKU (NOLOCK)
                WHERE Consigneekey = @c_Consigneekey         
                AND Storerkey = @c_Storerkey         
                AND Sku = @c_Sku     

                IF @c_UDF01 > CONVERT(NVARCHAR(8),@dt_lottable04,112)
                BEGIN
                   GOTO NEXTLOOP
                END
             END
             --WL01 End

             UPDATE CONSIGNEESKU WITH (ROWLOCK)
             SET CONSIGNEESKU.UDF01 = CONVERT(NVARCHAR(8),@dt_lottable04,112), 
                 CONSIGNEESKU.EditWho = SUSER_SNAME(),
                 CONSIGNEESKU.EditDate = GETDATE()
             WHERE CONSIGNEESKU.Consigneekey = @c_Consigneekey 
             --AND CONSIGNEESKU.Consigneesku = @c_SKU            
             AND CONSIGNEESKU.Storerkey = @c_Storerkey         
             AND CONSIGNEESKU.Sku = @c_Sku                    
             
             IF @@ERROR <> 0 
             BEGIN
                SELECT @n_continue = 3
                SELECT @n_Err = 31212
                SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
                                   'Error Update ConsigneeSKU Table (ispUpdLastLot4ToConsigneeSku)'
             END          
	    	 END
NEXTLOOP:  --WL01    	
          FETCH NEXT FROM LASTPICKEXP_CUR INTO @c_Consigneekey, @c_Sku, @dt_lottable04
	    END
      CLOSE LASTPICKEXP_CUR 
      DEALLOCATE LASTPICKEXP_CUR 

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
    SELECT @b_success = 0  
    IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
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
    execute nsp_logerror @n_err, @c_errmsg, 'ispUpdLastLot4ToConsigneeSku'  
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
    RETURN  
   END  
   ELSE  
   BEGIN  
    SELECT @b_success = 1  
    WHILE @@TRANCOUNT > @n_starttcnt  
    BEGIN  
     COMMIT TRAN  
    END  
   END                                      
END

GO