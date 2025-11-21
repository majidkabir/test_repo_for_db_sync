SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispLoadplanDetAllow2Del                             	      */
/* Creation Date: 21-Jul-2009                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Finalize Transfer			                                      */
/*                                                                      */
/* Called By: nep_n_cst_loadplandetail.Event ue_deleteinstancerules     */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver Purposes                                    */
/* 21-Jul-2009  SHONG   1.0 Initial Version                             */
/* 07-Jan-2010  NJOW01  1.1 157940 - allow deleting LoadplanDetail if   */ 
/*                          orders.Status < '9' and Loadplan.FinalizeFlag='N'*/
/*                          new storerconfig 'AllowDelLPDetPicking'     */
/************************************************************************/
CREATE PROC [dbo].[ispLoadplanDetAllow2Del]
   @c_LoadKey  NVARCHAR(10),
   @c_OrderKey NVARCHAR(10),
   @n_Allow    int OUTPUT,  -- 0=Not Allow, 1=Allow
   @c_ErrMsg   NVARCHAR(215) OUTPUT
AS
BEGIN
   DECLARE @c_Status       NVARCHAR(10)
   
   DECLARE @c_FinalizeFlag NVARCHAR(1),    --NJOW01
           @c_Storerkey    NVARCHAR(15),
           @b_Success      int,        
           @n_err          int,        
           @c_authority    NVARCHAR(1)     
           
   SET @n_Allow = 0
   SET @c_ErrMsg = ''

   SELECT @c_Status = STATUS, @c_Storerkey = Storerkey --NJOW01
   FROM   ORDERS WITH (NOLOCK)
   WHERE  OrderKey = @c_OrderKey
   
   SELECT @c_FinalizeFlag = FinalizeFlag --NJOW01
   FROM Loadplan WITH (NOLOCK)
   WHERE Loadkey = @c_Loadkey

   -- If Order Status = '0' then allow to delete loadplan detail
   IF @c_Status = '0'
   BEGIN
      SET @n_Allow = 1
      GOTO EXIT_PROC
   END

   --NJOW01 Start
   SELECT @b_success = 0
   EXECUTE nspGetRight '', -- facility
           @c_storerkey, 
           null,         -- Sku
           'AllowDelLPDetPicking',  -- Configkey
           @b_success    output,
           @c_authority  output, 
           @n_err        output,
           @c_errmsg     output

   IF @c_authority = '1' AND @c_FinalizeFlag = 'N' AND @c_status < '9'
   BEGIN
      SET @n_Allow = 1
      GOTO EXIT_PROC   	  
   END
   --NJOW01 End
   
   IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @c_OrderKey) AND @c_Status >= '3'
   BEGIN
      SET @c_ErrMsg = 'Pick In Progress (PickHeader-Order), Not allow to delete. (ispLoadplanDetAllow2Del)'
      GOTO EXIT_PROC
   END
   ELSE
   IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_LoadKey
             AND (OrderKey = '' OR OrderKey IS NULL) ) AND @c_Status >= '3'
   BEGIN
      SET @c_ErrMsg = 'Pick In Progress (PickHeader-Load), Not allow to delete. (ispLoadplanDetAllow2Del)'
      GOTO EXIT_PROC
   END
   ELSE
   IF EXISTS(SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE LoadKey = @c_LoadKey
             AND OrderKey = @c_OrderKey ) AND @c_Status >= '3'
   BEGIN
      SET @c_ErrMsg = 'Pick In Progress (RefKeyLookup), Not allow to delete. (ispLoadplanDetAllow2Del)'
      GOTO EXIT_PROC
   END
   SET @n_Allow = 1

EXIT_PROC:
END

GO