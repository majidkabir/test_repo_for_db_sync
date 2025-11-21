SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--

-- Definition for stored procedure isp_update_Sku : 
-- 29 March 2014  TLTING  Performance tune
-- 24 Feb 2017    TLTING  Performance tune

CREATE PROC [dbo].[isp_update_Sku]
AS
BEGIN
	DECLARE @n_continue 		  int
	      , @n_starttcnt		  int		-- Holds the current transaction count  
			, @b_debug		     int
			, @n_counter		  int
			, @c_ExecStatements nvarchar(4000)
         , @c_sku            NVARCHAR(20)
         , @c_storerkey      NVARCHAR(15)
         , @b_Success	     int 
         , @n_err		        int 
         , @c_errmsg	        NVARCHAR(250)

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

        SELECT @n_starttcnt = @@TRANCOUNT 
        
        SELECT @b_debug = 0
	     SELECT @b_success = 0
	     SELECT @n_continue = 1

     
        -- Start Looping Sku table 
 	     SELECT @c_sku = ''	
        SELECT @n_counter = 0


   WHILE @@TRANCOUNT > 0 
        COMMIT TRAN 
         


   DECLARE CUR_Storer CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT SKU.storerkey FROM SKU (NOLOCK) WHERE SKU.ABC IS NULL
   AND EXISTS (    SELECT 1  
	     FROM Storer (NOLOCK) 
        WHERE [Type] = '1' AND    SKU.storerkey = Storer.storerkey) 
                  GROUP BY SKU.storerkey
 
 

   OPEN CUR_Storer

   FETCH NEXT FROM CUR_Storer INTO @c_storerkey
  
   WHILE @@FETCH_STATUS <> -1
   BEGIN
  
         DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT RTRIM(SKU)
	        FROM SKU (NOLOCK)
	       WHERE ABC IS NULL 
          AND storerkey = @c_storerkey

         OPEN CUR1

         FETCH NEXT FROM CUR1 INTO @c_sku 
  
          WHILE @@FETCH_STATUS <> -1
           BEGIN
	         --WHILE (@n_continue=1)	
	         --BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT 'Sku', @c_sku 
                  SELECT 'Storerkey', @c_storerkey 
               END

               IF @b_debug = 1 SELECT 'Started Get sku...'


               IF @b_debug = 1
               BEGIN
                  SELECT 'Updating Sku from SKU table...'
                  SELECT 'SKU', @c_sku
                  SELECT 'Storerkey', @c_storerkey 
               END

               BEGIN TRAN

               UPDATE SKU WITH (ROWLOCK)
                 SET ABC = 'B', Trafficcop = NULL, EditDate = GETDATE()
               WHERE Sku = @c_sku
                 AND Storerkey = @c_storerkey

               IF @b_debug = 1
               BEGIN
                  SELECT 'Update Sku from SKU table is Done!'
               END
              
               IF @@ERROR = 0
               BEGIN 
                 COMMIT TRAN
               END
               ELSE
               BEGIN
                  ROLLBACK TRAN
                  SELECT @n_continue = 3
                  SELECT @n_err = 65002
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert records failed (isp_update_Sku)'  
               END
                  FETCH NEXT FROM CUR1 INTO @c_sku 
           END -- While 1=1 
           CLOSE CUR1
           DEALLOCATE CUR1 
          
         FETCH NEXT FROM CUR_Storer INTO  @c_storerkey
   END -- While 1=1 
   CLOSE CUR_Storer
   DEALLOCATE CUR_Storer 

	-- Drop Temp Table
--	DROP TABLE TMPTBLSKU2 


/* #INCLUDE <SPTPA01_2.SQL> */  
IF @n_continue=3  -- Error Occured - Process And Return  
BEGIN  
   SELECT @b_success = 0  
   IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
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

   EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_update_Sku'  
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
   RETURN  
END  
END


GO