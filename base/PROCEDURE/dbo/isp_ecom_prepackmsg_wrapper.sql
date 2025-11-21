SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Ecom_PrePackMsg_Wrapper                             */
/* Creation Date: 2022-04-14                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-19434 [CN]Rituals_EcomPacking_Show GiftWrapping Massage */
/*        : in Screen                                                   */
/*                                                                      */
/* Called By: nep_n_cst_visual_pack_ecom.of_prepackmsg                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-04-14  Wan      1.0   Created & Combine DevOps Script           */
/************************************************************************/
CREATE PROC [dbo].[isp_Ecom_PrePackMsg_Wrapper]
     @c_TaskBatchNo        NVARCHAR(10) 
   , @c_Orderkey           NVARCHAR(10) 
   , @b_Success            NVARCHAR(4000) = 1    OUTPUT         
   , @c_ErrMsg             NVARCHAR(4000) = ''   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT            = @@TRANCOUNT
         , @n_Continue           INT            = 1
         , @c_Facility           NVARCHAR(5)    = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         
         , @c_EcomPrePackMsg_SP  NVARCHAR(30)   = '' 

         , @c_SQL                NVARCHAR(2000) = ''
         , @c_SQLParms           NVARCHAR(2000) = ''
    
   SET @b_Success = 1          
   SET @c_errmsg   = ''

   SET @c_TaskBatchNo = ISNULL(@c_TaskBatchNo,'') 
   SET @c_Orderkey    = ISNULL(@c_Orderkey,'')

   IF @c_Orderkey = ''
   BEGIN
      IF @c_TaskBatchNo <> ''
      BEGIN
         SELECT TOP 1 
                  @c_Facility = o.Facility
               ,  @c_Storerkey= o.StorerKey
         FROM dbo.PackTask AS pt (NOLOCK) 
         JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = pt.Orderkey
         WHERE pt.TaskBatchNo = @c_TaskBatchNo
         ORDER BY pt.RowRef
      END
   END
   ELSE 
   BEGIN    
      SELECT @c_Facility = o.Facility
            ,@c_Storerkey= o.StorerKey
      FROM dbo.ORDERS AS o WITH (NOLOCK)
      WHERE o.OrderKey = @c_Orderkey   
   END
         
   SELECT @c_EcomPrePackMsg_SP = fgr.Authority FROM dbo.fnc_SelectGetRight( @c_Facility, @c_Storerkey, '', 'EcomPrePackMsg') AS fgr

   IF @c_EcomPrePackMsg_SP IN ('1', '0', '')
   BEGIN
      GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(@c_EcomPrePackMsg_SP) AND TYPE = 'P')
   BEGIN
      GOTO QUIT_SP
   END
   
   SET @c_SQL = N'EXEC ' + @c_EcomPrePackMsg_SP
              + '  @c_TaskBatchNo  = @c_TaskBatchNo'
              + ', @c_Orderkey     = @c_Orderkey'
              + ', @b_Success      = @b_Success OUTPUT'    
              + ', @c_ErrMsg       = @c_ErrMsg  OUTPUT'
              
   SET @c_SQLParms = N'@c_TaskBatchNo  NVARCHAR(10)'
                   + ',@c_Orderkey     NVARCHAR(10)'
                   + ',@b_Success      NVARCHAR(4000) OUTPUT' 
                   + ',@c_ErrMsg       NVARCHAR(4000) OUTPUT'
              
   EXEC sp_ExecuteSQL @c_SQL
                     ,@c_SQLParms    
                     ,@c_TaskBatchNo
                     ,@c_Orderkey  
                     ,@b_Success    OUTPUT 
                     ,@c_ErrMsg     OUTPUT
QUIT_SP:

END -- procedure

GO