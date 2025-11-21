SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/        
/* Store Procedure: isp_ValidatePickDetail                                   */        
/* Creation Date:                                                            */        
/* Copyright: IDS                                                            */        
/* Written by: YTWan                                                         */        
/*                                                                           */        
/* Purpose: SOS#253738. MARS Pickdetail Validation                           */        
/*                                                                           */        
/* Called By: PowerBuilder Upon Pickdetail ue_wrapup Event                   */        
/*                                                                           */        
/* PVCS Version: 1.2                                                         */   
/*                                                                           */        
/* Version: 5.4                                                              */        
/*                                                                           */        
/* Data Modifications:                                                       */        
/*                                                                           */        
/* Updates:                                                                  */        
/* Date         Author    Ver.  Purposes                                     */  
/* 19-Nov-2012  YTWan     1.1   Only Check Order Type 'M-DELV', 'M-MISC',    */
/*                              'M-SCPO' (Wan01)                             */   
/* 29-Mar-2018  Wan02     1.2   WM Pickdetail Validation - Add @n_WarningNo  */
/*                              , @c_ProceedWithWarning                      */
/*****************************************************************************/        
        
CREATE PROCEDURE [dbo].[isp_ValidatePickDetail]        
         @c_OrderKey             NVARCHAR(10) 
      ,  @c_Lot                  NVARCHAR(10)  
      ,  @c_Loc                  NVARCHAR(10)  
      ,  @c_ID                   NVARCHAR(18) 
      ,  @n_Qty                  INT        
      ,  @b_ReturnCode           INT = 0              OUTPUT   -- 0 = OK, -1 = Error, 1 = Warning  
      ,  @n_err                  INT = 0              OUTPUT        
      ,  @c_errmsg               NVARCHAR(255) = ''   OUTPUT   
      ,  @n_WarningNo            INT = 0              OUTPUT   --(Wan02)
      ,  @c_ProceedWithWarning   CHAR(1) = 'N'                 --(Wan02) 
AS 
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @b_Success     INT

   DECLARE  @c_Facility    NVARCHAR(5)
         ,  @c_Storerkey   NVARCHAR(15)  
         ,  @c_HostWHCode  NVARCHAR(10)
         ,  @c_ConfigKey   NVARCHAR(30)
         ,  @c_SValue      NVARCHAR(10) 
         ,  @c_OrderType   NVARCHAR(10)
         ,  @c_Lottable01  NVARCHAR(18) 

   SET @b_ReturnCode = 0
   SET @n_err        = 0
   SET @c_errmsg     = ''

   SET @b_Success    = 1
   SET @c_Storerkey  = ''
   SET @c_HostWHCode = ''
   SET @c_ConfigKey  = ''
   SET @c_SValue     = ''

   SELECT @c_Storerkey = RTRIM(Storerkey)
         ,@c_Lottable01= ISNULL(RTRIM(Lottable01),'')
   FROM LOTATTRIBUTE WITH (NOLOCK)
   WHERE Lot = @c_Lot

   SELECT @c_Facility  = RTRIM(Facility)
         ,@c_HostWHCode= ISNULL(RTRIM(HostWHCode),'')
   FROM LOC WITH (NOLOCK)
   WHERE Loc = @c_Loc

   ------------------IDSTH CHKMARSPICK--------------------
   SET @c_ConfigKey  = 'CHKMARSPICK' 
   EXECUTE dbo.nspGetRight @c_Facility          -- facility
                        ,  @c_Storerkey         -- Storerkey
                        ,  NULL                 -- Sku
                        ,  @c_Configkey         -- Configkey
                        ,  @b_Success      OUTPUT
                        ,  @c_SValue       OUTPUT
                        ,  @n_err          OUTPUT
                        ,  @c_errmsg       OUTPUT

   IF @b_Success = 1 AND @c_SValue = '1'
   BEGIN
      SELECT @c_OrderType = ISNULL(RTRIM(Type),0)
      FROM ORDERS WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey


      IF @c_OrderType IN ('M-DELV', 'M-MISC', 'M-SCPO') AND      -- (Wan01) 
         NOT ((@c_OrderType = 'M-DELV' AND @c_Lottable01 = 'U' AND
               @c_HostWHCode IN ('0001','0002','0003'))  OR
              (@c_OrderType = 'M-MISC' AND @c_Lottable01 = 'U' AND
               @c_HostWHCode IN ('0001','0002'))         OR
              (@c_OrderType = 'M-SCPO' AND @c_Lottable01 = 'S' AND
               @c_HostWHCode IN ('0003')))
      BEGIN
         SET @b_ReturnCode = -1
         SET @c_errmsg = 'Invalid Lottable01 and HostWHCode. Please Check.'
         GOTO QUIT_SP
      END
   END
   ------------------IDSTH CHKMARSPICK--------------------
   QUIT_SP:        
END
-- end procedure   

GO