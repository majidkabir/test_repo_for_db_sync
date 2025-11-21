SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispPKISGETPKINFO01                                 */  
/* Creation Date: 17-Feb-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-18938 - MYS-PRESTIGE-Modify Scan Pack Module            */  
/*                                                                      */  
/* Called By: isp_PackIsCapturePackInfo_Wrapper                         */
/*            Storerconfig: PackIsCapturePackInfo_SP                    */
/*                                                                      */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 17-Feb-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 09-Jun-2023  WLChooi  1.1  WMS-22798 Change to Codelkup.Notes (WL01) */
/************************************************************************/   
CREATE   PROCEDURE [dbo].[ispPKISGETPKINFO01]
   @c_Pickslipno        NVARCHAR(10),
   @c_Facility          NVARCHAR(5),
   @c_Storerkey         NVARCHAR(15),
   @c_CapturePackInfo   NVARCHAR(5)   OUTPUT,
   @b_Success           INT           OUTPUT,
   @n_Err               INT           OUTPUT, 
   @c_ErrMsg            NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue     INT,
           @c_CSGNKeyList  NVARCHAR(MAX) = ''
   
   SELECT @c_Storerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   JOIN PICKHEADER PH (NOLOCK) ON PH.Orderkey = OH.OrderKey
   JOIN STORER ST (NOLOCK) ON OH.ConsigneeKey = ST.Storerkey 
   WHERE PH.PickHeaderKey = @c_Pickslipno

   SELECT TOP 1 @c_CSGNKeyList = ISNULL(CODELKUP.Notes,'')   --WL01
   FROM CODELKUP (NOLOCK)
   WHERE CODELKUP.LISTNAME = 'PRESCONFIG' AND CODELKUP.Code = 'WEIGHT'
   AND CODELKUP.Storerkey = @c_Storerkey

   IF EXISTS (SELECT 1
              FROM PICKHEADER (NOLOCK)
              JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.OrderKey
              JOIN STORER (NOLOCK) ON ORDERS.ConsigneeKey = STORER.Storerkey
              WHERE PICKHEADER.PickHeaderKey = @c_Pickslipno
              AND ORDERS.ConsigneeKey IN (SELECT DISTINCT ColValue 
                                          FROM dbo.fnc_DelimSplit(',',@c_CSGNKeyList) FDS))
   BEGIN
      SET @c_CapturePackInfo = '1'
   END
   ELSE
   BEGIN
      SET @c_CapturePackInfo = '0'
   END

   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPKISGETPKINFO01'  
       --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO