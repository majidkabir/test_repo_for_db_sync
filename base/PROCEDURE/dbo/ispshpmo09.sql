SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO09                                            */
/* Creation Date: 23-Sep-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:  WLChooi                                                    */
/*                                                                         */
/* Purpose: WMS-17995 - CN Kellogg's Automaticlly check lot according      */
/*          consigneekey                                                   */
/*                                                                         */
/* Called By: ispPostMBOLShipWrapper                                       */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 22-SEP-2021  WLChooi 1.0   Created - DEVOPS Script Combine              */
/***************************************************************************/  
CREATE PROC [dbo].[ispSHPMO09]  
(     @c_MBOLkey     NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 

   DECLARE @c_SKU             NVARCHAR(20)
         , @c_Consigneekey    NVARCHAR(15)
         , @c_Lottable03      NVARCHAR(50)
         , @c_SUSR3           NVARCHAR(10)
         , @n_LotCheck        INT = 0
         , @c_MaxLot          NVARCHAR(50)

   SET @b_Success   = 1 
   SET @n_Err       = 0  
   SET @c_ErrMsg    = ''
   SET @b_Debug     = '0' 
   SET @n_Continue  = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   --Main Process
   BEGIN TRAN

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      DECLARE CUR_OD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT OD.Storerkey, OH.ConsigneeKey, OD.SKU, MAX(OD.Lottable03), ISNULL(ST.SUSR3,'')
         FROM MBOLDETAIL MD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON MD.Orderkey = OH.Orderkey
         JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
         JOIN STORER ST (NOLOCK) ON ST.ConsigneeFor = OH.StorerKey AND ST.StorerKey = OH.ConsigneeKey
         WHERE MD.Mbolkey = @c_MBOLKey
         GROUP BY OD.Storerkey, OH.ConsigneeKey, OD.SKU, ISNULL(ST.SUSR3,'')
      
      OPEN CUR_OD  
  
      FETCH NEXT FROM CUR_OD INTO @c_Storerkey, @c_Consigneekey, @c_SKU, @c_Lottable03, @c_SUSR3

      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN
         IF @c_SUSR3 <> '1'
            GOTO NEXT_LOOP

         SET @n_LotCheck = 0
         SET @c_MaxLot   = ''

         SELECT @n_LotCheck = ISNULL(COUNT(1),0)
              , @c_MaxLot   = ISNULL(MAX(CS.UDF01),'')
         FROM ConsigneeSKU CS (NOLOCK)
         WHERE CS.StorerKey = @c_Storerkey
         AND CS.ConsigneeSKU = @c_SKU
         AND CS.ConsigneeKey = @c_Consigneekey

         IF @n_LotCheck = 0
         BEGIN
            INSERT INTO ConsigneeSKU (ConsigneeKey, ConsigneeSKU, StorerKey, SKU, UDF01)
            SELECT @c_Consigneekey, @c_SKU, @c_Storerkey, @c_SKU, @c_Lottable03

            SELECT @n_err = @@ERROR  
         
            IF @n_err <> 0  
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72500    
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                                + ': INSERT Failed On ConsigneeSKU Table for Storerkey = ' + LTRIM(RTRIM(@c_Storerkey)) 
                                + ' AND SKU = ' + LTRIM(RTRIM(@c_SKU))   
                                + ' AND ConsigneeKey = ' + LTRIM(RTRIM(@c_Consigneekey)) + ' (ispSHPMO09)'   
                                + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            END 
         END
         ELSE IF @n_LotCheck > 0 AND @c_MaxLot < @c_Lottable03
         BEGIN
            UPDATE ConsigneeSKU
            SET UDF01 = @c_Lottable03
            WHERE StorerKey = @c_Storerkey
            AND SKU = @c_SKU
            AND ConsigneeKey = @c_Consigneekey
            AND ConsigneeSKU = @c_SKU

            IF @n_err <> 0  
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72505    
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                                + ': UPDATE Failed On ConsigneeSKU Table for Storerkey = ' + LTRIM(RTRIM(@c_Storerkey)) 
                                + ' AND SKU = ' + LTRIM(RTRIM(@c_SKU))   
                                + ' AND ConsigneeKey = ' + LTRIM(RTRIM(@c_Consigneekey)) + ' (ispSHPMO09)'   
                                + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            END
         END

         NEXT_LOOP:
         FETCH NEXT FROM CUR_OD INTO @c_Storerkey, @c_Consigneekey, @c_SKU, @c_Lottable03, @c_SUSR3
      END
      CLOSE CUR_OD
      DEALLOCATE CUR_OD
   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_OD') IN (0 , 1)
   BEGIN
      CLOSE CUR_OD
      DEALLOCATE CUR_OD   
   END
      
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO09'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO