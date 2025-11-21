SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPalletMgmt_BackEnd_Finalize                        */
/* Creation Date: 20-APR-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-16767 - TH Pallet Management Auto finalize                 */
/*                                                                         */
/* Called By: SQL Backend Job                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispPalletMgmt_BackEnd_Finalize]    
AS  
BEGIN  	
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Success             INT,
           @n_Err                 INT,
           @c_ErrMsg              NVARCHAR(255),
           @n_Continue            INT,
           @n_StartTranCount      INT
                                  
   DECLARE @c_Storerkey           NVARCHAR(15),
           @c_Facility            NVARCHAR(5),
           @c_Status_Opt1        NVARCHAR(30),
           @c_PMKey               NVARCHAR(10)              
           
   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT

   IF @@TRANCOUNT = 0
      BEGIN TRAN
      	   
   IF @n_continue IN(1,2)
   BEGIN
  	  DECLARE CUR_CONFIG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Storerkey, Facility, Option1
         FROM STORERCONFIG (NOLOCK)
         WHERE Configkey = 'PalletMgmtBackEndFinalize'
         AND Svalue  = '1'               

      OPEN CUR_CONFIG  
      
      FETCH NEXT FROM CUR_CONFIG INTO @c_Storerkey, @c_Facility, @c_Status_Opt1
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)            
      BEGIN
      	 IF ISNULL(@c_Status_Opt1,'') NOT IN ('1','2','3','4','5','6','7','8')
      	    SET @c_Status_Opt1 = '3'
      	    
      	 DECLARE CUR_PALLETMGMT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      	    SELECT DISTINCT PM.PMKey
      	    FROM PALLETMGMT PM (NOLOCK)
      	    JOIN PALLETMGMTDETAIL PMD (NOLOCK) ON PM.PMKey = PMD.PMKey
      	    WHERE PM.Status = @c_Status_Opt1
      	    AND PM.Facility = CASE WHEN ISNULL(@c_Facility, '') <> '' THEN @c_Facility ELSE PM.Facility END
      	    AND PMD.FromStorerkey = @c_Storerkey  	
      	    AND PMD.Type = 'TRF'
      	    AND DATEDIFF(hour, PM.Adddate, GETDATE()) >= 48
      	    
         OPEN CUR_PALLETMGMT  
      
         FETCH NEXT FROM CUR_PALLETMGMT INTO @c_PMKey
      
         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)            
         BEGIN
         	
         	  EXEC ispFinalizePalletMgmt
         	    @c_PMKey = @c_PMKey,
         	    @b_Success = @b_Success OUTPUT,
         	    @n_Err = @n_Err OUTPUT,
         	    @c_ErrMsg = @c_ErrMsg OUTPUT,
         	    @c_BackEndFinalize = 'Y'
         	    
            IF  @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = RTRIM(@c_Errmsg) +  ' (ispPalletMgmt_BackEnd_Finalize)'
            END
                       	
            FETCH NEXT FROM CUR_PALLETMGMT INTO @c_PMKey
         END
         CLOSE CUR_PALLETMGMT
         DEALLOCATE CUR_PALLETMGMT
      	          	          	   
         FETCH NEXT FROM CUR_CONFIG INTO @c_Storerkey, @c_Facility, @c_Status_Opt1      	
      END
      CLOSE CUR_CONFIG
      DEALLOCATE CUR_CONFIG    
   END
      	            
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPalletMgmt_BackEnd_Finalize'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO