SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_SODetailExpectedItems_Arch                          */  
/* Creation Date: 02-NOV-2016                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: WMS-600 - enhancement of return ASN's population            */  
/*        : New DW to call SP                                           */  
/* Called By:  d_ds_sodetail_expected_items_arch                        */  
/*          :                                                           */  
/* PVCS Version: 1.2                                                   */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 20-Oct-2017  SPChin    INC0018638 - Enhancement                      */  
/* 22-JUL-2018  Wan       1.2 Channel Management                        */   
/* 18-Sep-2019  TLTING01  1.3 Dynamic SQL cache recompile               */  
/************************************************************************/  
CREATE PROC [dbo].[isp_SODetailExpectedItems_Arch]   
            @c_Orderkey    NVARCHAR(10)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @n_Err             INT   
  
         , @n_Cnt             INT       
         , @c_Lot             NVARCHAR(10)  
         , @c_ArchiveDB       NVARCHAR(30)  
         , @c_ExecSQL         NVARCHAR(4000)  
         , @c_ExecArgs        NVARCHAR(4000)    
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_Err = 0  
   SELECT  @c_ExecSQL = '', @c_ExecArgs = ''     

   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
     
   SET @c_ArchiveDB = ''  
   SELECT @c_ArchiveDB = ISNULL(RTRIM(NSQLValue),'') FROM NSQLCONFIG WITH (NOLOCK)  
   WHERE ConfigKey='ArchiveDBName'  
  
   IF @c_ArchiveDB = ''  
   BEGIN  
      GOTO QUIT_SP  
   END  
  
   SET @c_ExecSQL=N' DECLARE CUR_PICKLOT CURSOR FAST_FORWARD READ_ONLY FOR'  
                 + ' SELECT PD.Lot'  
                 + ' FROM ' + @c_ArchiveDB + '.dbo.ORDERDETAIL  OD WITH (NOLOCK)'  
                 + ' JOIN ' + @c_ArchiveDB + '.dbo.PICKDETAIL   PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)'  
                 +                                                             ' AND(OD.OrderLineNumber = PD.OrderLineNumber)'  
                 + ' LEFT JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)'  
                 + ' WHERE OD.Orderkey = @c_Orderkey '  
                 + ' AND   OD.ShippedQty > 0'  
                 + ' AND LA.Lot IS NULL'  
                 + ' ORDER BY PD.Lot'  
   
   SET @c_ExecArgs = N'@c_Orderkey Nvarchar(10)'

   EXECUTE sp_ExecuteSQL @c_ExecSQL , @c_ExecArgs, @c_Orderkey 
  

   OPEN CUR_PICKLOT  
     
   FETCH NEXT FROM CUR_PICKLOT INTO @c_Lot  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @n_Continue = 1  
      BEGIN TRAN  
        
      SET @c_ExecSQL=N' INSERT INTO LOTATTRIBUTE ('  
               + '  Storerkey'  
               + ', Sku'  
               + ', Lot'  
               + ', Lottable01, Lottable02, Lottable03, Lottable04, Lottable05'  
               + ', Lottable06, Lottable07, Lottable08, Lottable09, Lottable10'  
               + ', Lottable11, Lottable12, Lottable13, Lottable14, Lottable15'  
               + ', Flag'  
                + ')'  
               + '  SELECT'  
               + '  Storerkey'  
               + ', Sku'  
               + ', Lot'  
               + ', Lottable01, Lottable02, Lottable03, Lottable04, Lottable05'  
               + ', Lottable06, Lottable07, Lottable08, Lottable09, Lottable10'  
               + ', Lottable11, Lottable12, Lottable13, Lottable14, Lottable15'  
               + ', Flag'  
               + '  FROM ' + @c_ArchiveDB + '.dbo.LOTATTRIBUTE WITH (NOLOCK)'  
               + '  WHERE Lot = @c_Lot '   

      SET @c_ExecArgs = N'@c_Lot Nvarchar(10)'

      EXECUTE sp_ExecuteSQL @c_ExecSQL, @c_ExecArgs, @c_Lot 
  
  

   --   EXECUTE sp_ExecuteSQL @c_ExecSQL  
        
      IF @@ERROR <> 0   
      BEGIN  
         SET @n_Continue = 3  
         GOTO NEXT_LOT  
      END   
  
      SET @c_ExecSQL=N'DELETE FROM ' + @c_ArchiveDB + '.dbo.LOTATTRIBUTE WITH (ROWLOCK)'  
                    +' WHERE Lot = @c_Lot '   
  
      SET @c_ExecArgs = N'@c_Lot Nvarchar(10)'

      EXECUTE sp_ExecuteSQL @c_ExecSQL, @c_ExecArgs, @c_Lot 
   
     -- EXECUTE sp_ExecuteSQL @c_ExecSQL  
  
      IF @@ERROR <> 0   
      BEGIN  
         SET @n_Continue = 3  
         GOTO NEXT_LOT  
      END   
  
      COMMIT TRAN  
  
      NEXT_LOT:  
  
      IF @n_Continue=3   
      BEGIN  
         ROLLBACK TRAN  
         --GOTO NEXT_LOT   --INC0018638  
      END  
        
      FETCH NEXT FROM CUR_PICKLOT INTO @c_Lot   
   END  
  
   CLOSE CUR_PICKLOT  
   DEALLOCATE CUR_PICKLOT  
  
QUIT_SP:  
   IF CURSOR_STATUS( 'GLOBAL', 'CUR_PICKLOT') in (0 , 1)    
   BEGIN  
      CLOSE CUR_PICKLOT  
      DEALLOCATE CUR_PICKLOT  
   END  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
  
   SET @c_ExecSQL=N'SELECT OD.Sku'    
         + ',ManufacturerSku = ISNULL(RTRIM(OD.ManufacturerSku),'''')'  
         + ',OD.PackKey'    
         + ',OD.UOM'     
         + ',pokey = OD.ORDERKey'    
         + ',Qtyexpected=SUM(PD.Qty)'  
         + ',DESCR = ISNULL(RTRIM(SKU.DESCR),'''')'     
         + ',SKU.StorerKey'  
         + ',OD.OrderLineNumber'    
         + ',OD.OrderKey'  
         + ',OH.Facility'  
         + ',ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'''')'    
         + ',ExternLineNo   = ISNULL(RTRIM(OD.ExternLineNo),'''')'    
         + ',Lottable01 = ISNULL(RTRIM(LA.Lottable01),'''')'     
         + ',Lottable02 = ISNULL(RTRIM(LA.Lottable02),'''')'    
         + ',Lottable03 = ISNULL(RTRIM(LA.Lottable03),'''')'    
         + ',LA.Lottable04'  
         + ',LA.Lottable05'  
         + ',Lottable06 = ISNULL(RTRIM(LA.Lottable06),'''')'    
         + ',Lottable07 = ISNULL(RTRIM(LA.Lottable07),'''')'    
         + ',Lottable08 = ISNULL(RTRIM(LA.Lottable08),'''')'    
         + ',Lottable09 = ISNULL(RTRIM(LA.Lottable09),'''')'  
         + ',Lottable10 = ISNULL(RTRIM(LA.Lottable10),'''')'  
         + ',Lottable11 = ISNULL(RTRIM(LA.Lottable11),'''')'    
         + ',Lottable12 = ISNULL(RTRIM(LA.Lottable12),'''')'    
         + ',LA.Lottable13'    
         + ',LA.Lottable14'  
         + ',LA.Lottable15'  
         + ',UserDefine01 = ISNULL(RTRIM(OD.UserDefine01),'''')'   
         + ',UserDefine02 = ISNULL(RTRIM(OD.UserDefine02),'''')'   
         + ',UserDefine03 = ISNULL(RTRIM(OD.UserDefine03),'''')'   
         + ',UserDefine04 = ISNULL(RTRIM(OD.UserDefine04),'''')'   
         + ',UserDefine05 = ISNULL(RTRIM(OD.UserDefine05),'''')'   
         + ',UserDefine06 = ISNULL(RTRIM(OD.UserDefine06),'''')'   
         + ',UserDefine07 = ISNULL(RTRIM(OD.UserDefine07),'''')'   
         + ',UserDefine08 = ISNULL(RTRIM(OD.UserDefine08),'''')'   
         + ',UserDefine09 = ISNULL(RTRIM(OD.UserDefine09),'''')'  
         + ',Itemclass    = ISNULL(RTRIM(SKU.Itemclass),'''')'  
         + ',Channel      = ISNULL(RTRIM(OD.Channel),'''')'          --(Wan01)  
         + ' FROM ' + @c_ArchiveDB + '.dbo.ORDERS      OH WITH (NOLOCK)'  
         + ' JOIN ' + @c_ArchiveDB + '.dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)'  
         + ' JOIN SKU SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey)'  
         +                            ' AND(OD.Sku = SKU.Sku)'  
         + ' JOIN ' + @c_ArchiveDB + '.dbo.PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)'                                                                    
         +                                                            ' AND(OD.OrderLineNumber = PD.OrderLineNumber)'   
         + ' JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (PD.Lot = LA.Lot)'                                                                   
         + ' WHERE OD.Orderkey = @c_Orderkey '  
         + ' AND   OD.ShippedQty > 0'  
         + ' GROUP BY OD.Sku'    
         +          ',ISNULL(RTRIM(OD.ManufacturerSku),'''')'  
         +          ',OD.PackKey'    
         +          ',OD.UOM'     
         +          ',ISNULL(RTRIM(SKU.DESCR),'''')'     
         +          ',SKU.StorerKey'  
         +          ',OD.OrderLineNumber'    
         +          ',OD.OrderKey'  
         +          ',OH.Facility'  
         +          ',ISNULL(RTRIM(OH.ExternOrderkey),'''')'    
         +          ',ISNULL(RTRIM(OD.ExternLineNo),'''')'    
         +          ',ISNULL(RTRIM(LA.Lottable01),'''')'     
         +          ',ISNULL(RTRIM(LA.Lottable02),'''')'    
         +          ',ISNULL(RTRIM(LA.Lottable03),'''')'    
         +          ',LA.Lottable04'  
         +          ',LA.Lottable05'  
         +          ',ISNULL(RTRIM(LA.Lottable06),'''')'    
         +          ',ISNULL(RTRIM(LA.Lottable07),'''')'    
         +          ',ISNULL(RTRIM(LA.Lottable08),'''')'    
         +          ',ISNULL(RTRIM(LA.Lottable09),'''')'  
         +          ',ISNULL(RTRIM(LA.Lottable10),'''')'  
         +          ',ISNULL(RTRIM(LA.Lottable11),'''')'    
         +          ',ISNULL(RTRIM(LA.Lottable12),'''')'    
         +          ',LA.Lottable13'    
         +          ',LA.Lottable14'  
         +          ',LA.Lottable15'  
         +          ',ISNULL(RTRIM(OD.UserDefine01),'''')'   
         +          ',ISNULL(RTRIM(OD.UserDefine02),'''')'   
         +          ',ISNULL(RTRIM(OD.UserDefine03),'''')'   
         +          ',ISNULL(RTRIM(OD.UserDefine04),'''')'   
         +          ',ISNULL(RTRIM(OD.UserDefine05),'''')'   
         +          ',ISNULL(RTRIM(OD.UserDefine06),'''')'   
         +          ',ISNULL(RTRIM(OD.UserDefine07),'''')'   
         +          ',ISNULL(RTRIM(OD.UserDefine08),'''')'   
         +          ',ISNULL(RTRIM(OD.UserDefine09),'''')'  
         +          ',ISNULL(RTRIM(SKU.Itemclass),'''')'   
         +          ',ISNULL(RTRIM(OD.Channel),'''')'                --(Wan01)           
         + ' ORDER BY OD.Orderkey'  
         +          ',OD.OrderLineNumber'  

   SET @c_ExecArgs = N'@c_Orderkey Nvarchar(10)'

   EXECUTE sp_ExecuteSQL @c_ExecSQL , @c_ExecArgs, @c_Orderkey 
    
--   EXECUTE sp_ExecuteSQL @c_ExecSQL  
END -- procedure  

GO