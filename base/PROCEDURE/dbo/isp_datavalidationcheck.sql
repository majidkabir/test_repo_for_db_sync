SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_DataValidationCheck                                     */
/* Creation Date: 07-Apr-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  Test Extended Validation call from Extended validation     */
/*        :  Screen                                                     */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 14/08/2019   WLChooi   1.1 WMS-9973 Pack Confirm Extended Validation */
/*                            PrePack Extended Validation (WL01)        */
/* 19/05/2021   WLChooi   1.2 WMS-17048 Channel Transfer Finalize       */
/*                            Extended Validation (WL02)                */
/* 24/02/2023   NJOW01    1.3 WMS-21757 Unallocation extended validation*/
/* 24/02/2023   NJOW01    1.3 DEVOPS Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_DataValidationCheck] 
            @c_ValidationSP      NVARCHAR(50)
         ,  @c_ValidationRules   NVARCHAR(60)
         ,  @c_Parm1             NVARCHAR(60)
         ,  @c_Parm2             NVARCHAR(60)
         ,  @c_Parm3             NVARCHAR(60)
         ,  @c_Parm4             NVARCHAR(60)
         ,  @c_Parm5             NVARCHAR(60)
         ,  @b_Success           INT = 0  OUTPUT 
         ,  @c_errmsg            NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE  @n_StartTCnt      INT
         ,  @n_Continue       INT
         ,  @n_Exists         INT
         ,  @c_Source         NVARCHAR(50) 
         ,  @n_Idx            INT
         ,  @c_Sql            NVARCHAR(512)
         ,  @c_ParmName       NVARCHAR(60)

   SET @b_success  = 1
   SET @c_errmsg   = ''

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_Idx      = 1
   SET @c_Sql      = ''

   SET @c_Parm1    = CASE WHEN @c_Parm1 IS NULL THEN '' ELSE @c_Parm1 END
   SET @c_Parm2    = CASE WHEN @c_Parm2 IS NULL THEN '' ELSE @c_Parm2 END
   SET @c_Parm3    = CASE WHEN @c_Parm3 IS NULL THEN '' ELSE @c_Parm3 END
   SET @c_Parm4    = CASE WHEN @c_Parm4 IS NULL THEN '' ELSE @c_Parm4 END
   SET @c_Parm5    = CASE WHEN @c_Parm5 IS NULL THEN '' ELSE @c_Parm5 END

   IF @c_ValidationSP = 'isp_ASN_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM RECEIPTDETAIL WITH (NOLOCK) WHERE Receiptkey = @c_Parm1 '     
                 + CASE WHEN @c_Parm2 = '' THEN '' ELSE 'AND ReceiptLineNumber = @c_Parm2' END
      SET @c_Source = 'Receipt Line' 
   END

   IF @c_ValidationSP = 'isp_ADJ_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM ADJUSTMENTDETAIL WITH (NOLOCK) WHERE Adjustmentkey = @c_Parm1 '
         
      SET @c_Source = 'Adjustment Line'       
   END

   IF @c_ValidationSP = 'isp_TRF_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM TRANSFERDETAIL WITH (NOLOCK) WHERE Transferkey = @c_Parm1 '    
                 + CASE WHEN @c_Parm2 = '' THEN '' ELSE 'AND TransferLineNumber = @c_Parm2'  END 
      SET @c_Source = 'Transfer Line'
   END

   IF @c_ValidationSP = 'isp_MOVE_ExtendedValidation'
   BEGIN
        SELECT Storerkey   AS Storerkey
            ,  Sku         AS Sku
            ,  @c_Parm1    AS Lot
            ,  @c_Parm2    AS FromLoc
            ,  @c_Parm3    AS FromID   
            ,  @c_Parm4    AS ToLoc
            ,  @c_Parm3    AS ToID   
            ,  ''          AS Status
            ,  ''          AS Lottable01
            ,  ''          AS Lottable02
            ,  ''          AS Lottable03
            ,  GETDATE()   AS Lottable04
            ,  GETDATE()   AS Lottable05
            ,  ''          AS Lottable06
            ,  ''          AS Lottable07
            ,  ''          AS Lottable08
            ,  ''          AS Lottable09
            ,  ''          AS Lottable10
            ,  ''          AS Lottable11
            ,  ''          AS Lottable12 
            ,  GETDATE()   AS Lottable13
            ,  GETDATE()   AS Lottable14
            ,  GETDATE()   AS Lottable15                              
            ,  Qty         AS Qty
            ,  0.00        AS Pallet
            ,  0.00        AS Cube    
            ,  0.00        AS Grosswgt 
            ,  0.00        AS Netwgt
            ,  0.00        AS otherunit1       
            ,  0.00        AS otherunit2 
            ,  ''          AS SourceKey          
            ,  ''          AS SourceType           
            ,  ''          AS PackKey            
            ,  ''          AS UOM                
            ,  0           AS UOMCalc            
            ,  GETDATE()   AS EffectiveDate
        INTO #MOVE
        FROM LOTxLOCxID WITH (NOLOCK)
        WHERE Lot = @c_Parm1
        AND   Loc = @c_Parm2
        AND   ID  = @c_Parm3
        AND   Qty > 0

      SET @c_Sql = N'SELECT @n_exists = 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE Lot = @c_Parm1 AND   Loc = @c_Parm2 AND ID = @c_Parm3 AND Qty > 0'
      SET @c_Source = 'Move Inventory'
   END

   IF @c_ValidationSP = 'isp_REPL_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE Lot = @c_Parm1 AND   Loc = @c_Parm2 AND ID = @c_Parm3 AND Qty > 0'
      SET @c_Source = 'Replenish Inventory'
   END

   IF @c_ValidationSP = 'isp_KIT_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM KITDETAIL WITH (NOLOCK) WHERE KITKey = @c_Parm1'

      SET @c_Source = 'Kitting'
   END

   IF @c_ValidationSP = 'isp_IQC_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM INVENTORYQCDETAIL WITH (NOLOCK) WHERE QC_Key = @c_Parm1'

      SET @c_Source = 'IQC Inventory'
   END

   IF @c_ValidationSP = 'isp_ALLOCATE_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM ORDERS WITH (NOLOCK) WHERE 1=1 '
                 + CASE WHEN @c_Parm1 = '' THEN '' ELSE 'AND Orderkey= @c_Parm1 ' END
                 + CASE WHEN @c_Parm2 = '' THEN '' ELSE 'AND Loadkey = @c_Parm2 ' END
                 + CASE WHEN @c_Parm3 = '' THEN '' ELSE 'AND UserDefine09 = @c_Parm3 ' END

      SET @c_Source = 'Allocate Doc #'
   END

   IF @c_ValidationSP = 'isp_LOAD_PopulateValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM LOADPLAN WITH (NOLOCK) WHERE Loadkey = @c_Parm1
                     AND EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Orderkey = @c_Parm2)'

      SET @c_Source = 'Either Load #/Orders #'
   END

   IF @c_ValidationSP = 'isp_MBOL_PopulateValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM MBOL WITH (NOLOCK) WHERE MBOLKey = @c_Parm1
                     AND EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Orderkey = @c_Parm2)'

      SET @c_Source = 'Either MBOL #/Orders #'
   END

   IF @c_ValidationSP = 'isp_LOAD_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_Parm1 AND Storerkey = @c_Parm2'

      SET @c_Source = 'Load Plan'
   END

   IF @c_ValidationSP = 'isp_MBOL_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM ORDERS WITH (NOLOCK) WHERE MBOLKey = @c_Parm1 AND Storerkey = @c_Parm2'

      SET @c_Source = 'MBOL'
   END

   IF @c_ValidationSP = 'isp_BKO_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM BOOKING_OUT WITH (NOLOCK) WHERE BookingNo = @c_Parm1'

      SET @c_Source = 'Booking Out'
   END

   IF @c_ValidationSP = 'isp_POD_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM POD WITH (NOLOCK) WHERE MBOLKey = @c_Parm1 AND MBOLLineNumber = @c_Parm2'

      SET @c_Source = 'Proof of Delivery'
   END

   IF @c_ValidationSP = 'isp_JOB_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM WORKORDERJOBDETAIL WITH (NOLOCK) WHERE JobKey = @c_Parm1'

      SET @c_Source = 'Job #'
   END

   --WL01 Start
   IF @c_ValidationSP = 'isp_Pack_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM PACKHEADER WITH (NOLOCK) WHERE Pickslipno = @c_Parm1'

      SET @c_Source = 'Pickslipno'
   END

   IF @c_ValidationSP = 'isp_PrePack_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM PICKHEADER WITH (NOLOCK) WHERE Pickheaderkey = @c_Parm1'

      SET @c_Source = 'Pickslipno'
   END
   --WL01 End

   --WL02 S
   IF @c_ValidationSP = 'isp_ChannelTRF_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM ChannelTransferDetail WITH (NOLOCK) WHERE ChannelTransferkey = @c_Parm1 '    
                 + CASE WHEN @c_Parm2 = '' THEN '' ELSE 'AND ChannelTransferLineNumber = @c_Parm2'  END 

      SET @c_Source = 'Channel Transfer Line'
   END
   --WL02 E
   
   --NJOW01 S
   IF @c_ValidationSP = 'isp_UNALLOCATE_ExtendedValidation'
   BEGIN
      SET @c_Sql = N'SELECT @n_exists = 1 FROM PICKDETAIL WITH (NOLOCK) WHERE 1=1 '
                 + CASE WHEN @c_Parm1 = '' THEN '' ELSE 'AND Pickdetailkey= @c_Parm1 ' END
                 + CASE WHEN @c_Parm2 = '' THEN '' ELSE 'AND Orderkey = @c_Parm2 ' END

      SET @c_Source = 'UnAllocate Doc #'
   END
   --NJOW01 E

   IF @c_Sql <> ''
   BEGIN
      SET @n_exists = 0
      EXEC sp_ExecuteSQL @c_Sql
                        ,N'@n_exists INT     OUTPUT
                        ,  @c_Parm1  NVARCHAR(60)     
                        ,  @c_Parm2  NVARCHAR(60)
                        ,  @c_Parm3  NVARCHAR(60)
                        ,  @c_Parm4  NVARCHAR(60)
                        ,  @c_Parm5  NVARCHAR(60)'
                        ,  @n_exists OUTPUT
                        ,  @c_Parm1
                        ,  @c_Parm2
                        ,  @c_Parm3
                        ,  @c_Parm4
                        ,  @c_Parm5

      IF @n_exists = 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg = @c_Source + ' Not found.'
         GOTO QUIT
      END  
   END 

   SET @c_Sql = ''

   DECLARE CUR_PARMS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Parameter_Name
   FROM   INFORMATION_SCHEMA.Parameters WITH (NOLOCK)
   WHERE  Specific_Name = @c_ValidationSP
   ORDER BY ORDINAL_POSITION
   
   OPEN CUR_PARMS
   
   FETCH NEXT FROM CUR_PARMS INTO @c_ParmName 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_Sql = @c_Sql + ', ' + @c_ParmName 

      SET @c_Sql = @c_Sql +
                     + CASE WHEN @c_ParmName LIKE '%rules'   THEN '= @c_ValidationRules '      
                            WHEN @c_ParmName LIKE '%success' THEN '= @b_success OUTPUT '
                            WHEN @c_ParmName LIKE '%errmsg'  THEN '= @c_errmsg  OUTPUT'  
                            WHEN @c_ParmName LIKE '%errormsg'THEN '= @c_errmsg  OUTPUT'  
                            ELSE '= @c_Parm' + RTRIM(CONVERT(VARCHAR(1), @n_idx))
                            END

      SET @n_Idx = @n_Idx 
                 + CASE WHEN @c_ParmName LIKE '%rules'   THEN 0
                        WHEN @c_ParmName LIKE '%success' THEN 0
                        WHEN @c_ParmName LIKE '%errmsg'  THEN 0
                        WHEN @c_ParmName LIKE '%errormsg'THEN 0
                        ELSE 1
                        END

      FETCH NEXT FROM CUR_PARMS INTO @c_ParmName 
   END
   CLOSE CUR_PARMS
   DEALLOCATE CUR_PARMS 

   IF @c_Sql = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_ErrMsg = 'Stored Procedure: ' + @c_ValidationSP + ' Not found. Contact GIT Dev/Support team'
      GOTO QUIT
   END 
   ELSE
   BEGIN
      SET @c_Sql = 'EXEC ' + @c_ValidationSP + ' ' + SUBSTRING(@c_Sql, 2, LEN(@c_Sql) - 1)

      EXEC sp_ExecuteSQL @c_Sql
                  ,N'@c_Parm1  NVARCHAR(60)     
                  ,  @c_Parm2  NVARCHAR(60)
                  ,  @c_Parm3  NVARCHAR(60)
                  ,  @c_Parm4  NVARCHAR(60)
                  ,  @c_Parm5  NVARCHAR(60)
                  ,  @c_ValidationRules NVARCHAR(60)
                  ,  @b_success   INT            OUTPUT   
                  ,  @c_errmsg    NVARCHAR(215)  OUTPUT'
                  ,  @c_Parm1
                  ,  @c_Parm2
                  ,  @c_Parm3
                  ,  @c_Parm4
                  ,  @c_Parm5
                  ,  @c_ValidationRules
                  ,  @b_success   OUTPUT   
                  ,  @c_errmsg    OUTPUT 
   END 

QUIT:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PARMS') in (0 , 1)  
   BEGIN
      CLOSE CUR_PARMS
      DEALLOCATE CUR_PARMS
   END

   IF @n_Continue = 3
   BEGIN 
      SET @b_Success = 0
   END

END -- procedure

GO