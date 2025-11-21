SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispFinalizeIQC                                              */
/* Creation Date: 21-Jul-2009                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Finalize Inventory QC                                       */
/*                                                                      */
/* Called By: n_cst_inventoryqc.Event ue_finalizeall                    */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 12-JAN-2015  YTWan     1.1 SOS#328603 - CN_PUMA_add verification for */
/*                            IQC (START)                               */
/* 09-NOV-2018  NJOW01    1.2 WMS-6868 Post finalize calling custom sp  */
/* 05-JUL-2021  WLChooi   1.3 WMS-17352 - Add @c_QC_LineNo as optional  */
/*                            input parameter for RDT (WL01)            */
/************************************************************************/
CREATE PROC [dbo].[ispFinalizeIQC] 
            @c_qc_key         NVARCHAR(10) 
         ,  @b_Success        INT = 0  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
         ,  @c_QC_LineNo      NVARCHAR(5) = ''   --WL01
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SQL             NVARCHAR(4000)

         , @c_QCLineNo        NVARCHAR(5)

         , @c_Storerkey       NVARCHAR(15) 
         , @c_Sku             NVARCHAR(20) 
         , @c_IQCValidationRules NVARCHAR(30)   --(Wan01)
         , @c_PostFinalizeIQCSP NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
     
   WHILE  @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN   
   END
   IF EXISTS ( SELECT 1
               FROM   INVENTORYQCDETAIL WITH (NOLOCK)
               JOIN LOTxLOCxID WITH (NOLOCK) ON  (INVENTORYQCDETAIL.FromLot = LOTxLOCxID.Lot)
                                             AND (INVENTORYQCDETAIL.FromLoc = LOTxLOCxID.Loc)  
                                             AND (INVENTORYQCDETAIL.FromID  = LOTxLOCxID.ID) 
               WHERE INVENTORYQCDETAIL.QC_Key = @c_qc_key 
               AND  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) < INVENTORYQCDETAIL.toQty
               AND  INVENTORYQCDETAIL.QCLineNo = CASE WHEN ISNULL(@c_QC_LineNo, '') = '' THEN INVENTORYQCDETAIL.QCLineNo ELSE @c_QC_LineNo END   --WL01
              ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Inventory has been moved away from the original place!' 
      GOTO QUIT
   END

   --(Wan01) - START
   -- SOS#328603  Extented Validation for IQC using Codelkup 
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT @c_StorerKey = StorerKey
      FROM INVENTORYQC WITH (NOLOCK)
      WHERE QC_Key = @c_QC_Key

      SELECT @c_IQCValidationRules = SC.sValue
      FROM STORERCONFIG SC (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
      WHERE SC.StorerKey = @c_StorerKey
      AND SC.Configkey = 'IQCExtendedValidation'

      IF ISNULL(@c_IQCValidationRules,'') <> ''
      BEGIN

         EXEC isp_IQC_ExtendedValidation @c_QC_Key = @c_qc_key 
                                       , @c_IQCValidationRules = @c_IQCValidationRules 
                                       , @b_Success  = @b_Success OUTPUT
                                       , @c_ErrMsg = @c_ErrMsg OUTPUT
         IF @b_Success <> 1
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 81055
            GOTO QUIT
         END
      END
      ELSE   
      BEGIN  
         SELECT @c_IQCValidationRules = SC.sValue    
         FROM STORERCONFIG SC (NOLOCK) 
         WHERE SC.StorerKey = @c_StorerKey 
         AND SC.Configkey = 'IQCExtendedValidation'    
         
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_IQCValidationRules) AND type = 'P')          
         BEGIN          
            SET @c_SQL = 'EXEC ' + @c_IQCValidationRules + ' @c_qc_key, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          

            EXEC sp_executesql @c_SQL,          
                 N'@c_qc_key NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'
                , @c_qc_key          
                , @b_Success  OUTPUT          
                , @n_Err      OUTPUT          
                , @c_ErrMsg   OUTPUT 
    

            IF @b_Success <> 1     
            BEGIN    
               SET @n_Continue = 3    
               SET @n_err=81060     
               GOTO QUIT
            END         
         END  
      END            
   END --    IF @n_Continue = 1 OR @n_Continue = 2
   --(Wan01)-- END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN

      DECLARE CUR_IQCDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT QCLineNo
      FROM   INVENTORYQCDETAIL WITH (NOLOCK)
      WHERE  QC_Key = @c_qc_key 
      AND    Status <> '9'
      AND    FinalizeFlag <> 'Y'
      AND    QCLineNo = CASE WHEN ISNULL(@c_QC_LineNo, '') = '' THEN QCLineNo ELSE @c_QC_LineNo END   --WL01

      OPEN CUR_IQCDET

      FETCH NEXT FROM CUR_IQCDET INTO @c_QCLineNo

      WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN

         BEGIN TRAN 
         UPDATE INVENTORYQCDETAIL WITH (ROWLOCK)
            SET FinalizeFlag = 'Y'
         WHERE  QC_Key = @c_qc_key 
         AND    QCLineNo = @c_QCLineNo
         AND    Status <> '9'
         AND    FinalizeFlag <> 'Y'

         SET @n_err = @@ERROR
         IF @n_err <> 0     
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 81065   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE INVENTORYQCDETAIL Failed. (ispFinalizeIQC)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END

         FETCH NEXT FROM CUR_IQCDET INTO @c_QCLineNo

      END -- While 
      CLOSE CUR_IQCDET
      DEALLOCATE CUR_IQCDET
   END 

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF NOT EXISTS ( SELECT 1
                      FROM INVENTORYQCDETAIL WITH (NOLOCK)
                      WHERE QC_Key = @c_QC_Key
                      AND FinalizeFlag = 'N' )
      BEGIN
         BEGIN TRAN             
         UPDATE INVENTORYQC WITH (ROWLOCK)
         SET FinalizeFlag = 'Y'
         WHERE QC_Key = @c_QC_Key
         AND FinalizeFlag <> 'Y'
            
         SET @n_err = @@ERROR
         IF @n_err <> 0     
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE INVENTORYQC Failed. (ispFinalizeIQC)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            ROLLBACK TRAN
            GOTO QUIT
         END
         ELSE
         BEGIN         	
            COMMIT TRAN
            
            --NJOW01 S
            SET @c_PostFinalizeIQCSP = ''
            EXEC nspGetRight 
                 @c_Facility=''
                ,@c_StorerKey=@c_StorerKey
                ,@c_sku=NULL
                ,@c_ConfigKey='PostFinalizeIQCSP'
                ,@b_Success=@b_Success OUTPUT
                ,@c_authority=@c_PostFinalizeIQCSP OUTPUT
                ,@n_err=@n_err OUTPUT
                ,@c_errmsg=@c_errmsg OUTPUT  

            IF EXISTS (
                   SELECT 1
                   FROM   sys.objects o
                   WHERE  NAME         = @c_PostFinalizeIQCSP
                   AND    TYPE     = 'P'
               )
            BEGIN            
            	  BEGIN TRAN
                SET @b_Success = 0  
                EXECUTE dbo.ispPostFinalizeIQCWrapper 
                        @c_qc_key=@c_qc_key,
                        @c_PostFinalizeIQCSP=@c_PostFinalizeIQCSP,
                        @b_Success=@b_Success OUTPUT,
                        @n_Err=@n_err OUTPUT,
                        @c_ErrMsg=@c_errmsg OUTPUT  
                
                IF @n_err<>0
                BEGIN
                    SET @n_continue = 3 
                    SET @n_err = 81070
                    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute ispPostFinalizeIQCWrapper Failed. (ispFinalizeIQC)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                    ROLLBACK TRAN
                END
                ELSE
                   COMMIT TRAN
            END         
            --NJOW01 E      
         END
      END
   END

QUIT:
   WHILE  @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN   
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispFinalizeIQC'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END   
END -- procedure

GO