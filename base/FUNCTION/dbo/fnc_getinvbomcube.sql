SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store Procedure:  fnc_GetInvBOMCube                                        */  
/* Creation Date: 05-08-2010                                                  */  
/* Copyright: IDS                                                             */  
/* Written by:                                                                */  
/*                                                                            */  
/* Purpose:  Stored Procedure for PUTAWAY from ASN                            */  
/*                                                                            */  
/* Called from nspRDTPASTD                                                    */  
/*                                                                            */  
/* PVCS Version: 1.3                                                          */  
/*                                                                            */  
/* Version: 5.4                                                               */  
/*                                                                            */  
/* Data Modifications:                                                        */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author        Ver   Purposes                                  */  
/******************************************************************************/  
CREATE FUNCTION [dbo].[fnc_GetInvBOMCube]   
  ( @n_Type         INT, -- 1 = STDCUBE , 2 = STDGROSSWGT  
    @c_Location     NVARCHAR(10),  
    @c_ID           NVARCHAR(18) )  
RETURNS Float  
AS  
BEGIN  
  
   DECLARE @c_CalculateByBOM NVARCHAR(1),    
      @c_BOMSKU         NVARCHAR(20),    
      @n_LOQTY          INT,    
      @c_Storerkey      NVARCHAR(15),  
      @c_PackKey        NVARCHAR(10),  
      @f_STDCUBE        DECIMAL(15,5),    
      @f_TotalCube      DECIMAL(15,5),    
      @f_STDGROSSWGT    DECIMAL(15,5),    
      @f_TotalGROSSWGT  DECIMAL(15,5),    
      @n_CaseCnt        INT,  
      @f_CSTDCUBE       DECIMAL(15,5),      
      @f_Length         DECIMAL(15,5),      
      @f_Width          DECIMAL(15,5),      
      @f_Height         DECIMAL(15,5),  
      @f_PPalletTotStdCube   DECIMAL(15,5),   
      @f_PPPalletTotStdGrossWgt DECIMAL(15,5),  
      @c_PrePackByBOM   NVARCHAR(1),  
      @n_TotalBOMQTY    INT,  
      @f_BOMValue       FLOAT,  
      @c_ErrMSG         NVARCHAR(250),  
      @n_Err            INT  
      
   SET @f_BOMValue = 0   
   SET @c_Packkey = ''  
   SET @f_STDCUBE = 0  
   SET @f_Length  = 0   
   SET @f_Width   = 0   
   SET @f_Height  = 0  
   SET @n_CaseCnt = 0  
   SET @n_TotalBOMQTY = 0  
   SET @c_BOMSKU = ''  
   SET @n_LOQTY = 0   
   SET @c_Storerkey = ''  
   SET @f_PPalletTotStdCube = 0  
   SET @f_TotalCube = 0  
   SET @f_PPPalletTotStdGrossWgt  = 0   
   SET @f_TotalGROSSWGT = 0        
   SET @f_CSTDCUBE = 0  
  
   IF ISNULL(@c_Location,'') <> ''  
   BEGIN  
   IF NOT EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK) WHERE LOC = @c_Location )  
   BEGIN  
      SET @f_BOMValue = 0  
      GOTO QUIT_FUNCTION  
   END  

   IF NOT EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK) WHERE LOC = @c_Location AND (Qty - QtyAllocated - QtyPicked) > 0 )  
   BEGIN  
      SET @f_BOMValue = 0  
      GOTO QUIT_FUNCTION  
   END  
  
  
   DECLARE CUR_CUBIC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
   SELECT DISTINCT LA.Lottable03   
      ,SUM(LO.QTY)  
      ,LO.Storerkey  
   FROM   dbo.LOTxLOCxID LO WITH (NOLOCK)  
   INNER JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK)  
      ON  LA.LOT = LO.LOT  
   WHERE  LO.LOC = @c_Location  
   GROUP BY LA.Lottable03 , LO.Storerkey    
  
   OPEN CUR_CUBIC  
   FETCH NEXT FROM CUR_CUBIC INTO @c_BOMSKU, @n_LOQTY, @c_Storerkey --@f_STDCUBE , @f_Length, @f_Width, @f_Height  

   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
            
      SELECT @c_Packkey = PACKKEY,  
         @f_STDCUBE = SKU.STDCUBE,  
         @f_Length  = SKU.Length,   
         @f_Width   = SKU.Width,   
         @f_Height  = SKU.Height  
      FROM   SKU WITH (NOLOCK)  
      WHERE  SKU = @c_BOMSKU  
      AND    STORERKEY = @c_Storerkey    
  
              
              
      IF ISNULL(@c_Packkey,'') = ''  
      BEGIN  
         SET @f_BOMValue = 9999  
         GOTO QUIT_FUNCTION  
      END  

      SELECT @n_CaseCnt = CaseCnt FROM PACK WITH (NOLOCK)  
      WHERE PACKKEY = @c_Packkey  

      IF ISNULL(@n_CaseCnt,0) = 0  
      BEGIN  
         SET @f_BOMValue = 9999  
         GOTO QUIT_FUNCTION  
      END  
            
      SELECT @n_TotalBOMQTY = SUM(QTY)  FROM BILLOFMATERIAL WITH (NOLOCK)  
      WHERE SKU = @c_BOMSKU  
      AND STORERKEY = @c_Storerkey  

      IF ISNULL(@n_TotalBOMQTY,0) = 0  
      BEGIN  
         SET @f_BOMValue = 9999  
         GOTO QUIT_FUNCTION  
      END  
     
            
      IF ISNULL(@f_STDCUBE , 0) > 0  
      BEGIN  
         SET @f_TotalCube = @f_TotalCube + (  
                                    ( (@n_LOQTY/@n_TotalBOMQTY) -- Component SKU Qty  
                                    / @n_CaseCnt)  
                                    * @f_STDCUBE)    

         SET @f_TotalGROSSWGT  =  @f_STDGROSSWGT * @n_CaseCnt  
      END  
      ELSE  
      BEGIN  
         SET @f_CSTDCUBE = ISNULL(@f_Length,0) * ISNULL(@f_Width,0) *  ISNULL(@f_Height,0)  
         SET @f_TotalCube = @f_TotalCube + (  
                                    ( (@n_LOQTY/@n_TotalBOMQTY) -- Component SKU Qty  
                                    / @n_CaseCnt)  
                                    * @f_STDCUBE)     

         SET @f_TotalGROSSWGT = @f_STDGROSSWGT * @n_CaseCnt  
      END  

         FETCH NEXT FROM CUR_CUBIC INTO @c_BOMSKU , @n_LOQTY, @c_Storerkey  
      END  

      CLOSE CUR_CUBIC  
      DEALLOCATE CUR_CUBIC   
  
      SET @f_PPalletTotStdCube = @f_TotalCube       
      SET @f_PPPalletTotStdGrossWgt = @f_TotalGROSSWGT        
  
      IF @n_Type = 1  
      BEGIN  
         SET @f_BOMValue = @f_PPalletTotStdCube  
      END  
      ELSE  
      BEGIN  
         SET @f_BOMValue = @f_PPPalletTotStdGrossWgt  
      END  
   END  
   ELSE IF ISNULL(@c_ID,'') <> ''  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK) WHERE ID = @c_ID )  
      BEGIN  
         SET @f_BOMValue = 0  

         GOTO QUIT_FUNCTION  
      END  

      DECLARE CUR_CUBIC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
      SELECT DISTINCT LA.Lottable03   
            ,SUM(LO.QTY)  
            ,LO.Storerkey  
      FROM   dbo.LOTxLOCxID LO WITH (NOLOCK)  
      INNER JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK)  
                  ON  LA.LOT = LO.LOT  
      WHERE  LO.ID = @c_ID  
      --AND    LO.Storerkey = @c_Storerkey  
      AND    LO.QTY>0  
      GROUP BY LA.Lottable03 , LO.Storerkey    
  
     
      OPEN CUR_CUBIC  
      FETCH NEXT FROM CUR_CUBIC INTO @c_BOMSKU, @n_LOQTY, @c_Storerkey --@f_STDCUBE , @f_Length, @f_Width, @f_Height  
            
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
            
         SELECT @c_Packkey = PACKKEY,  
            @f_STDCUBE = SKU.STDCUBE,  
            @f_Length  = SKU.Length,   
            @f_Width   = SKU.Width,   
            @f_Height  = SKU.Height  
         FROM   SKU WITH (NOLOCK)  
         WHERE  SKU = @c_BOMSKU  
         AND    STORERKEY = @c_Storerkey    

         IF ISNULL(@c_Packkey,'') = ''  
         BEGIN  
            SET @f_BOMValue = 9999  
            GOTO QUIT_FUNCTION  
         END  
            
         SELECT @n_CaseCnt = CaseCnt FROM PACK WITH (NOLOCK)  
         WHERE PACKKEY = @c_Packkey  
  
         IF ISNULL(@n_CaseCnt,0) = 0  
         BEGIN  
            SET @f_BOMValue = 9999  
            GOTO QUIT_FUNCTION  
         END  
            
         SELECT @n_TotalBOMQTY = SUM(QTY)  FROM BILLOFMATERIAL WITH (NOLOCK)  
         WHERE SKU = @c_BOMSKU  
         AND STORERKEY = @c_Storerkey  
      
         IF ISNULL(@n_TotalBOMQTY,0) = 0  
         BEGIN  
            SET @f_BOMValue = 9999  
            GOTO QUIT_FUNCTION  
         END  
            
         IF ISNULL(@f_STDCUBE , 0) > 0  
         BEGIN  
         SET @f_TotalCube = @f_TotalCube + (  
                                    ( (@n_LOQTY/@n_TotalBOMQTY) -- Component SKU Qty  
                                    / @n_CaseCnt)  
                                    * @f_STDCUBE)    

            SET @f_TotalGROSSWGT  =  @f_STDGROSSWGT * @n_CaseCnt  
         END  
         ELSE  
         BEGIN  
            SET @f_CSTDCUBE = ISNULL(@f_Length,0) * ISNULL(@f_Width,0) *  ISNULL(@f_Height,0)  
            SET @f_TotalCube = @f_TotalCube + (  
                                       ( (@n_LOQTY/@n_TotalBOMQTY) -- Component SKU Qty  
                                       / @n_CaseCnt)  
                                       * @f_STDCUBE)     

            SET @f_TotalGROSSWGT = @f_STDGROSSWGT * @n_CaseCnt  
         END  
  
         FETCH NEXT FROM CUR_CUBIC INTO @c_BOMSKU , @n_LOQTY, @c_Storerkey  
      END  
  
      CLOSE CUR_CUBIC  
      DEALLOCATE CUR_CUBIC   
  
      SET @f_PPalletTotStdCube = @f_TotalCube       
      SET @f_PPPalletTotStdGrossWgt = @f_TotalGROSSWGT        
  
      IF @n_Type = 1  
      BEGIN  
         SET @f_BOMValue = @f_PPalletTotStdCube  
      END  
      ELSE  
      BEGIN  
         SET @f_BOMValue = @f_PPPalletTotStdGrossWgt  
      END  
   END  
  
   QUIT_FUNCTION:  
     
  
   RETURN @f_BOMValue  
END

GO