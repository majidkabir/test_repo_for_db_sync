SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_ReplToFPA_Wave_PickSlip1_2                     */  
/* Creation Date: 08-FEB-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#269535- Replensihment Report for IDSHK LOR principle    */  
/*          - Replenish To Forward Pick Area (FPA)                      */  
/*          - Printed together with Move Ticket & Pickslip in a         */  
/*            composite report                                          */  
/*                                                                      */  
/* Called By: RCM - Popup Pickslip WavePlan                             */  
/*          : Duplicate from nsp_ReplenishToFPA_Order_Summary           */  
/*          : Datawindow - r_dw_replenishment_fpa_wave_pickslip_1_2     */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/************************************************************************/  
CREATE PROC  [dbo].[isp_ReplToFPA_Wave_PickSlip1_2]  
             @c_Key_Type  NVARCHAR(13)  
AS  
BEGIN  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE  @n_continue       INT           
         ,  @n_starttcnt      INT  
  
   DECLARE @b_debug           INT  
         , @b_success         INT  
         , @n_err             INT  
         , @c_errmsg          NVARCHAR(255)  
  
        
   DECLARE @c_ExternOrderkey  NVARCHAR(50)   --tlting_ext  
         , @c_OrderKey        NVARCHAR(10)   
         , @n_Count           INT   
         , @n_TotalOrd        INT   
         , @n_TotalIN         INT   
         , @n_TotalDN         INT   
         , @n_TotalTN         INT  
  
   DECLARE @n_TotalOrd1       INT  
         , @n_TotalOrd2       INT   
         , @n_TotalOrd3       INT   
         , @n_TotalOrd4       INT   
         , @n_TotalOrd5       INT  
         , @n_TotalIN1        INT  
         , @n_TotalIN2        INT  
         , @n_TotalIN3        INT  
         , @n_TotalIN4        INT  
         , @n_TotalIN5        INT  
         , @n_TotalDN1        INT  
         , @n_TotalDN2        INT  
         , @n_TotalDN3        INT  
         , @n_TotalDN4        INT  
         , @n_TotalDN5        INT  
         , @n_TotalTN1        INT  
         , @n_TotalTN2        INT  
         , @n_TotalTN3        INT  
         , @n_TotalTN4        INT  
         , @n_TotalTN5        INT  
  
   DECLARE @c_Key             NVARCHAR(10)   
         , @c_Type            NVARCHAR(2)  
  
  
   SET @n_continue=1  
   SET @b_debug = 0  
  
   SET @c_Key  = LEFT(@c_Key_Type, 10)  
   SET @c_Type = RIGHT(@c_Key_Type,2)  
   
   SET @n_Count = 1  
  
   SET @n_TotalOrd = 0  
   SET @n_TotalIN  = 0  
   SET @n_TotalDN  = 0  
   SET @n_TotalTN  = 0  
  
   SET @n_TotalOrd1 = 0  
   SET @n_TotalOrd2 = 0  
   SET @n_TotalOrd3 = 0  
   SET @n_TotalIN1  = 0  
   SET @n_TotalIN2  = 0  
   SET @n_TotalIN3  = 0  
   SET @n_TotalDN1  = 0  
   SET @n_TotalDN2  = 0  
   SET @n_TotalDN3  = 0  
   SET @n_TotalTN1  = 0  
   SET @n_TotalTN2  = 0             
   SET @n_TotalTN3  = 0  
  
   CREATE TABLE #TEMPORDERS  (Temp1      NVARCHAR(30) NULL,  
                              Temp2      NVARCHAR(30) NULL,  
                              Temp3      NVARCHAR(30) NULL)  
  
   IF @c_Type = 'WP'  
   BEGIN  
      DECLARE C_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT DISTINCT ORDERS.ExternOrderkey  
      FROM WAVEDETAIL WITH (NOLOCK)  
      JOIN ORDERS     WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)  
      WHERE WAVEKEY = @c_Key  
      Order By ORDERS.ExternOrderkey  
        
      OPEN C_CUR  
        
      FETCH NEXT FROM C_CUR INTO @c_ExternOrderkey  
        
      WHILE @@FETCH_STATUS <> -1   
      BEGIN  
         IF @b_debug = 1  
         BEGIN  
            Print '@c_Type: '+ @c_Type   
            SELECT '@c_ExternOrderkey', @c_ExternOrderkey, '@n_Count', @n_Count  
         END  
  
         IF @n_Count = 1  
         BEGIN  
            INSERT INTO #TEMPORDERS (Temp1, Temp2, Temp3)  
            SELECT @c_ExternOrderkey, 'N', 'N'  
         END  
         ELSE IF @n_Count = 2  
         BEGIN  
            UPDATE #TEMPORDERS   
              SET Temp2 = @c_ExternOrderkey  
            WHERE Temp2 = 'N'  
         END  
         ELSE IF @n_Count = 3  
         BEGIN  
            UPDATE #TEMPORDERS   
              SET Temp3 = @c_ExternOrderkey  
            WHERE Temp3 = 'N'  
         END  
  
         SET @n_Count = @n_Count + 1  
         IF @n_Count > 3  
         BEGIN  
            SET @n_Count = 1  
         END  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT @n_Count ' @n_Count', @c_ExternOrderkey ' @c_ExternOrderkey'  
         END  
  
         FETCH NEXT FROM C_CUR INTO @c_ExternOrderkey  
      END -- While detail  
      CLOSE C_CUR  
      DEALLOCATE C_CUR  
   END -- @c_Type = 'WV'  
   ELSE IF @c_Type = 'LP'  
   BEGIN  
      DECLARE C_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT DISTINCT ORDERS.ExternOrderkey  
      FROM LOADPLANDETAIL WITH (NOLOCK)  
      JOIN ORDERS         WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)  
      WHERE LOADPLANDETAIL.LOADKEY = @c_Key  
      Order By ORDERS.ExternOrderkey  
        
      OPEN C_CUR  
        
      FETCH NEXT FROM C_CUR INTO @c_ExternOrderkey  
        
      WHILE @@FETCH_STATUS <> -1   
      BEGIN  
         IF @b_debug = 1  
         BEGIN  
            Print '@c_Type: '+ @c_Type   
            SELECT '@c_ExternOrderkey', @c_ExternOrderkey, '@n_Count', @n_Count  
         END  
  
         IF @n_Count = 1  
         BEGIN  
            INSERT INTO #TEMPORDERS (Temp1, Temp2, Temp3)  
            SELECT @c_ExternOrderkey, 'N', 'N'  
         END  
         ELSE IF @n_Count = 2  
         BEGIN  
            UPDATE #TEMPORDERS   
              SET Temp2 = ISNULL(@c_ExternOrderkey, '')  
            WHERE Temp2 = 'N'  
         END  
         ELSE IF @n_Count = 3  
         BEGIN  
            UPDATE #TEMPORDERS   
              SET Temp3 = ISNULL(@c_ExternOrderkey, '')  
            WHERE Temp3 = 'N'  
         END  
  
         SET @n_Count = @n_Count + 1  
         IF @n_Count > 3  
         BEGIN  
            SET @n_Count = 1  
         END  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT @n_Count ' @n_Count', @c_ExternOrderkey ' @c_ExternOrderkey'  
         END  
  
         FETCH NEXT FROM C_CUR INTO @c_ExternOrderkey  
      END -- While detail  
      CLOSE C_CUR  
      DEALLOCATE C_CUR  
   END -- @c_Type = 'LP'  
     
   SELECT @n_TotalOrd1= SUM(CASE WHEN SUBSTRING(Temp1, 1, 2) <> 'N' THEN 1 ELSE 0 END)  
         ,@n_TotalOrd2= SUM(CASE WHEN SUBSTRING(Temp2, 1, 2) <> 'N' THEN 1 ELSE 0 END)  
         ,@n_TotalOrd3= SUM(CASE WHEN SUBSTRING(Temp3, 1, 2) <> 'N' THEN 1 ELSE 0 END)  
         ,@n_TotalIN1 = SUM(CASE WHEN SUBSTRING(Temp1, 1, 2) = 'IN' THEN 1 ELSE 0 END)  
         ,@n_TotalIN2 = SUM(CASE WHEN SUBSTRING(Temp2, 1, 2) = 'IN' THEN 1 ELSE 0 END)  
         ,@n_TotalIN3 = SUM(CASE WHEN SUBSTRING(Temp3, 1, 2) = 'IN' THEN 1 ELSE 0 END)  
         ,@n_TotalDN1 = SUM(CASE WHEN SUBSTRING(Temp1, 1, 2) = 'DN' THEN 1 ELSE 0 END)  
         ,@n_TotalDN2 = SUM(CASE WHEN SUBSTRING(Temp2, 1, 2) = 'DN' THEN 1 ELSE 0 END)  
         ,@n_TotalDN3 = SUM(CASE WHEN SUBSTRING(Temp3, 1, 2) = 'DN' THEN 1 ELSE 0 END)  
         ,@n_TotalTN1 = SUM(CASE WHEN SUBSTRING(Temp1, 1, 2) = 'TN' THEN 1 ELSE 0 END)  
         ,@n_TotalTN2 = SUM(CASE WHEN SUBSTRING(Temp2, 1, 2) = 'TN' THEN 1 ELSE 0 END)  
         ,@n_TotalTN3 = SUM(CASE WHEN SUBSTRING(Temp3, 1, 2) = 'TN' THEN 1 ELSE 0 END)  
   FROM #TEMPORDERS (NOLOCK)  
  
   SET @n_TotalOrd = @n_TotalOrd1 + @n_TotalOrd2 + @n_TotalOrd3  
   SET @n_TotalIN  = @n_TotalIN1  + @n_TotalIN2  + @n_TotalIN3  
   SET @n_TotalDN  = @n_TotalDN1  + @n_TotalDN2  + @n_TotalDN3  
   SET @n_TotalTN  = @n_TotalTN1  + @n_TotalTN2  + @n_TotalTN3  
  
   SELECT ISNULL(Temp1, '')   
         ,CASE WHEN Temp2 = 'N' THEN '' ELSE ISNULL(Temp2, '') END   
         ,CASE WHEN Temp3 = 'N' THEN '' ELSE ISNULL(Temp3, '') END   
         ,@c_Key  
         ,suser_sname()  
         ,@n_TotalOrd  
         ,@n_TotalIN  
         ,@n_TotalDN  
         ,@n_TotalTN  
   FROM  #TEMPORDERS (NOLOCK)  
  
   DROP TABLE #TEMPORDERS  
  
END -- End of Proc  

GO