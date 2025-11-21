SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: lsp_XDockAllocation_Wrapper                        */  
/* Creation Date: 26-Jan-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Crossdock allocation                                        */  
/*                                                                      */  
/* Called By: XDock Allocation                                          */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 22-Feb-2018 Wan01    1.0   Try..Catch                                */
/* 2020-12-29  SWT01    1.1   Missing Execute Login As                  */
/* 15-Jan-2021 Wan02    1.2   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 26-Feb-2024 NJOW01  1.3    UWP-14044 ASN support XDOCK allocation by */
/*                            multiple externpokey per ASN              */
/************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_XDockAllocation_Wrapper]  
   @c_ReceiptKey NVARCHAR(10),    
   @b_Success    INT           OUTPUT,
   @n_Err        INT           OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT,
   @c_UserName   NVARCHAR(128) = ''
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue                     INT,
           @n_starttcnt                    INT,
           @c_StorerKey                    NVARCHAR(15),           
           @c_Facility                     NVARCHAR(5),
           @c_XDFinalizeAutoAllocatePickSO NVARCHAR(10),
           @c_Print_GRN_When_Allocate      NVARCHAR(10),
           @n_POCnt                        INT,
           @c_ExternPOKey                  NVARCHAR(20),
           @c_ExternStatus                 NVARCHAR(10),
           @c_POType                       NVARCHAR(10),
           @CUR_ALC                        CURSOR  --NJOW01
                                                      
   SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1
   
   SET @n_Err = 0
   IF SUSER_SNAME() <> @c_UserName        --(Wan02) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT , @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
   
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
   
      EXECUTE AS LOGIN=@c_UserName -- (SWT01) 
   END                                    --(Wan02) - END
   
   BEGIN TRY                              --(Wan01) - START
      SELECT @c_Storerkey = Storerkey,
             @c_Facility = Facility
      FROM RECEIPT (NOLOCK)
      WHERE Receiptkey = @c_Receiptkey
      
      SELECT @c_XDFinalizeAutoAllocatePickSO = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'XDFinalizeAutoAllocatePickSO')
      SELECT @c_Print_GRN_When_Allocate = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PRINT_GRN_WHEN_ALLOCATE')
   
      IF @n_continue IN(1,2) AND @c_XDFinalizeAutoAllocatePickSO = '1' 
      BEGIN
         --(Wan01) - Start Try..Catch
         BEGIN TRY  
            EXEC isp_XDOCKFinalizeAutoAllocate 
                @c_Receiptkey = @c_Receiptkey,
                @b_success = @b_success OUTPUT,
                @n_err = @n_err OUTPUT,
                @c_errmsg = @c_errmsg OUTPUT
         END TRY
         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_Err    = 553901
            SET @c_ErrMsg = ERROR_MESSAGE()      
            SET @c_ErrMsg = 'Error Executing isp_XDOCKFinalizeAutoAllocate.'  
                          + ' << ' + @c_ErrMsg + ' >>'          
         END CATCH
             
         --IF @n_err <> 0 -- Since isp_XDOCKFinalizeAutoAllocate Raise Error, error will catch
         --BEGIN
         --    SELECT @n_continue = 3
         --END                          
         --ELSE
         IF @n_Continue IN (1,2)
         BEGIN
            GOTO PRINTING    
         END
         --(Wan01) - END Try..Catch    
      END
   
      IF @n_continue IN(1,2) 
      BEGIN 
         SELECT @c_ExternPOKey = MAX(RD.ExternPOKey),
                @c_ExternStatus = MAX(PO.ExternStatus),
                @c_POType = MAX(PO.PoType),
                @n_Pocnt = COUNT(DISTINCT RD.ExternPOKey)
         FROM RECEIPTDETAIL RD(NOLOCK)
         LEFT JOIN PO (NOLOCK) ON RD.ExternPOkey = PO.ExternPokey AND PO.Storerkey = RD.Storerkey 
         WHERE RD.Receiptkey = @c_Receiptkey     
      
         --IF @n_pocnt > 1   --NJOW01 Removed
         --BEGIN
         --   SELECT @n_continue = 3  
         --   SELECT @n_Err = 553902
         --   SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
         --          ': More than 1 PO found in the Detail. (lsp_XDockAllocation_Wrapper)'             
         --END
         
         IF ISNULL(@c_ExternPOKey,'') <> ''
         BEGIN
            IF @c_ExternStatus = '9' 
            BEGIN            	
            	 --NJOW01 S
               SET @CUR_ALC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR               
               SELECT RD.ExternPOKey
               FROM RECEIPTDETAIL RD WITH (NOLOCK) 
               JOIN PO p WITH (NOLOCK) ON rd.pokey = p.pokey
               WHERE RD.ReceiptKey = @c_ReceiptKey 
               GROUP BY RD.ExternPOKey
               ORDER BY RD.ExternPOKey               
               
               OPEN @CUR_ALC
               
               FETCH NEXT FROM @CUR_ALC INTO @c_externpokey
               
               WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
               BEGIN            	
                  BEGIN TRY              
                        EXEC nsp_xdockorderprocessing 
                           @c_Externpokey = @c_Externpokey,
                           @c_Storerkey = @c_Storerkey, 
                           @c_docarton = 'Y',
                           @c_doroute = 'N',
                           @c_facility = @c_Facility 
                  END TRY
                  BEGIN CATCH                  	 
                     IF (XACT_STATE()) = -1  
                     BEGIN
                        ROLLBACK TRAN
                     END
                     
                     WHILE @@TRANCOUNT < @n_starttcnt
                     BEGIN
                        BEGIN TRAN
                     END 
                                       	
                     SET @n_Continue = 3
                     SET @n_Err    = 553903
                     SET @c_ErrMsg = ERROR_MESSAGE()   
                     SET @c_ErrMsg = 'Error Executing nsp_xdockorderprocessing.'  
                                   + ' << ' + @c_ErrMsg + ' >>'                                                                                              
                  END CATCH

                  FETCH NEXT FROM @CUR_ALC INTO @c_externpokey
               END   
               CLOSE @CUR_ALC     
               DEALLOCATE @CUR_ALC
               --NJOW01 E
               
               /*
               --(Wan01) - Start Try..Catch
               BEGIN TRY              
                     EXEC nsp_xdockorderprocessing 
                        @c_Externpokey = @c_Externpokey,
                        @c_Storerkey = @c_Storerkey, 
                        @c_docarton = 'Y',
                        @c_doroute = 'N',
                        @c_facility = @c_Facility 
               END TRY
               BEGIN CATCH                  	                	
                  SET @n_Continue = 3
                  SET @n_Err    = 553903
                  SET @c_ErrMsg = ERROR_MESSAGE()   
                  SET @c_ErrMsg = 'Error Executing nsp_xdockorderprocessing.'  
                                + ' << ' + @c_ErrMsg + ' >>'                        
               END CATCH
               --(Wan01) - END Try..Catch                                 
               */
            END
            ELSE
            BEGIN
               IF EXISTS(SELECT 1  
                        FROM STORER (NOLOCK)                                         
                           JOIN XDOCKSTRATEGY XD(NOLOCK) ON STORER.XDockStrategykey = XD.XDockStrategyKey  
                        WHERE STORER.StorerKey = @c_Storerkey
                        AND XD.Type = '02')
               BEGIN
            	    --NJOW01 S
                  SET @CUR_ALC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR               
                  SELECT RD.ExternPOKey
                  FROM RECEIPTDETAIL RD WITH (NOLOCK) 
                  JOIN PO p WITH (NOLOCK) ON rd.pokey = p.pokey
                  WHERE RD.ReceiptKey = @c_ReceiptKey 
                  GROUP BY RD.ExternPOKey
                  ORDER BY RD.ExternPOKey               
                  
                  OPEN @CUR_ALC
                  
                  FETCH NEXT FROM @CUR_ALC INTO @c_externpokey
                  
                  WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
                  BEGIN            	
                     BEGIN TRY              
                           EXEC nsp_xdockorderprocessing 
                              @c_Externpokey = @c_Externpokey,
                              @c_Storerkey = @c_Storerkey, 
                              @c_docarton = 'Y',
                              @c_doroute = 'N',
                              @c_facility = @c_Facility 
                     END TRY
                     BEGIN CATCH                  	 
                        IF (XACT_STATE()) = -1  
                        BEGIN
                           ROLLBACK TRAN
                        END
                        
                        WHILE @@TRANCOUNT < @n_starttcnt
                        BEGIN
                           BEGIN TRAN
                        END 
                     	
                        SET @n_Continue = 3
                        SET @n_Err    = 553904
                        SET @c_ErrMsg = ERROR_MESSAGE()   
                        SET @c_ErrMsg = 'Error Executing nsp_xdockorderprocessing.'  
                                      + ' << ' + @c_ErrMsg + ' >>'                        
                     END CATCH

                     FETCH NEXT FROM @CUR_ALC INTO @c_externpokey
                  END   
                  CLOSE @CUR_ALC     
                  DEALLOCATE @CUR_ALC
                  --NJOW01 E               	               	
               	
               	  /*               	 
                  --(Wan01) - Start Try..Catch
                  BEGIN TRY         
                     EXEC nsp_xdockorderprocessing 
                        @c_Externpokey = @c_Externpokey,
                        @c_Storerkey = @c_Storerkey, 
                        @c_docarton = 'Y',
                        @c_doroute = 'N',
                        @c_facility = @c_Facility 
                  END TRY
                  BEGIN CATCH
                     SET @n_Continue = 3
                     SET @n_Err    = 553904
                     SET @c_ErrMsg = ERROR_MESSAGE()   
                     SET @c_ErrMsg = 'Error Executing nsp_xdockorderprocessing.'  
                                   + ' << ' + @c_ErrMsg + ' >>'   
                  END CATCH
                  --(Wan01) - END Try..Catch
                  */
               END
               ELSE
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @n_Err = 553905
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                           ': Only Closed PO can be proceed for Allocation. (lsp_XDockAllocation_Wrapper)'             
               END  
            END           
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_Err = 553906
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                   ': Externpokey not found. (lsp_XDockAllocation_Wrapper)'           
         END
      END
   
      PRINTING:
      /*
      IF @n_continue IN(1,2) AND @c_Print_GRN_When_Allocate = '1'
      BEGIN
            IF @c_POType IN('5','6')  
            BEGIN
                  -- lw_receipt_maintenance.tab_master.Event ue_print_grn_xdock()
            END
         
            IF @c_POType IN('8','8A')  
            BEGIN
                  -- lw_receipt_maintenance.tab_master.Event ue_print_grn_flowthru()
            END               
      END 
      */  
   END TRY
   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH                              --(Wan01) - END  
                          
   EXIT_SP:

   IF (XACT_STATE()) = -1  --NJOW01
   BEGIN                                     
      ROLLBACK TRAN                          
   END                                          
   
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
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_XDockAllocation_Wrapper'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        --(Wan01) 
      --RETURN       --(Wan01)
   END  
   ELSE  
      BEGIN  
         SELECT @b_success = 1  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
         --RETURN    --(Wan01)  
      END 
      
   --(Wan01) - Move Down   
   REVERT              
END  


GO